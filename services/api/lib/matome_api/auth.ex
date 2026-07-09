defmodule MatomeApi.Auth do
  import Ecto.Query

  alias MatomeApi.Auth.{Device, Guardian, KeyBundle, RefreshToken, TokenAllowlist, User}
  alias MatomeApi.Repo

  @access_ttl {15, :minutes}
  @refresh_ttl {30, :days}
  @reset_ttl {30, :minutes}

  # Session metadata capture (W4 #1872): `meta` is an optional map assembled
  # by the web layer — `%{ip, user_agent, login_method, device}` where
  # `device` is the client-supplied `%{"id", "platform", "display_name"}`.
  # Every key is optional; an empty map reproduces the pre-W4 behavior with
  # only the rotation fields (jti/family_id) populated.

  def get_user(id), do: Repo.get(User, id)

  def register_user(attrs, meta \\ %{}) do
    %User{}
    |> User.registration_changeset(normalize_credential(attrs))
    |> Repo.insert()
    |> with_tokens(meta)
  end

  @doc """
  Verifies the caller's login credential against the stored Argon2 hash.

  `credential` is intentionally opaque here — this task (#1852) separates the
  login secret from the encryption KEK, but that separation lives entirely on
  the CLIENT (see `.docs/internal/at-rest-key-flow.md` §1/§3): a legacy client
  passes the raw password; a migrated client passes
  `auth_secret = Argon2id(password, salt_auth)` instead. Core never derives
  one from the other and never sees the KEK — it just hashes/verifies
  whatever credential string arrives against the value that was hashed at
  registration for that same account.
  """
  def login(email, credential, meta \\ %{}) do
    user = Repo.get_by(User, email: String.downcase(email || ""))

    cond do
      user && Argon2.verify_pass(credential || "", user.password_hash) ->
        with_tokens({:ok, user}, meta)

      user ->
        {:error, :invalid_credentials}

      true ->
        # okt-audit AUDIT-CORE (task #1865): no account for this email, so
        # there's no `password_hash` to verify against — but skipping the
        # Argon2 call entirely makes this branch return far faster than the
        # "wrong password for a real account" branch above, and that timing
        # gap is itself a user-enumeration oracle. `Argon2.no_user_verify/0`
        # runs the same hash work against a fixed dummy hash so both
        # branches take comparable time.
        Argon2.no_user_verify()
        {:error, :invalid_credentials}
    end
  end

  @doc """
  Starts the password-reset flow. Always returns `:ok` regardless of whether the
  email matches an account, so callers cannot use it to enumerate users. When a
  user exists, a short-lived Guardian `reset` token is minted and emailed.
  """
  def request_password_reset(email) do
    email = String.downcase(email || "")

    case Repo.get_by(User, email: email) do
      %User{} = user ->
        {:ok, reset_token, _claims} =
          Guardian.encode_and_sign(user, %{}, token_type: "reset", ttl: @reset_ttl)

        MatomeApi.Auth.UserNotifier.deliver_reset_password(user, reset_token)
        :ok

      _ ->
        :ok
    end
  end

  @doc """
  Completes a password reset: verifies the `reset` token, sets the new password,
  revokes all existing refresh tokens for that user, and issues a fresh session.
  Returns `{:ok, auth}`, `{:error, %Ecto.Changeset{}}` (weak password), or
  `{:error, :invalid_reset_token}`.
  """
  def reset_password(token, new_password, meta \\ %{}) do
    with {:ok, claims} <- Guardian.decode_and_verify(token, %{"typ" => "reset"}),
         {:ok, %User{} = user} <- Guardian.resource_from_claims(claims),
         {:ok, updated} <-
           user
           |> User.password_update_changeset(%{password: new_password})
           |> Repo.update() do
      Repo.delete_all(from(t in RefreshToken, where: t.user_id == ^updated.id))
      issue_tokens(updated, meta)
    else
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
      _ -> {:error, :invalid_reset_token}
    end
  end

  def refresh(refresh_token, meta \\ %{})

  def refresh(refresh_token, meta) when is_binary(refresh_token) do
    with {:ok, claims} <- Guardian.decode_and_verify(refresh_token, %{"typ" => "refresh"}),
         %RefreshToken{} = stored <- active_refresh_token(refresh_token),
         {:ok, user} <- Guardian.resource_from_claims(claims) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Rotation (W4 #1872): the presented token is retained as a REVOKED row
      # rather than deleted, so a later replay of it is distinguishable from
      # a token that never existed — the reuse-detection seam W5 builds on.
      stored
      |> Ecto.Changeset.change(revoked_at: now, last_seen_at: now)
      |> Repo.update!()

      # W5 #1873: the access token minted alongside the rotated-out refresh
      # token is bound to its jti; bust any cached :active entry so it
      # cannot outlive the rotation on a warm cache.
      TokenAllowlist.invalidate(stored.jti)

      # The successor inherits the session identity (family, device, how the
      # session was originally established) and records the chain link; only
      # the network context (ip/user_agent) comes from the current request.
      meta =
        meta
        |> Map.put(:family_id, stored.family_id || Ecto.UUID.generate())
        |> Map.put(:rotated_from, stored.jti)
        |> Map.put(:device_id, stored.device_id)
        |> Map.put(:login_method, stored.login_method)

      issue_tokens(user, meta)
    else
      _ -> {:error, :invalid_refresh_token}
    end
  end

  def refresh(_refresh_token, _meta), do: {:error, :invalid_refresh_token}

  @doc """
  Ends the session the refresh token belongs to (W5 #1873): every live row
  in its family is revoked (`revoked_at` set — rows are retained per the W4
  audit seam, not deleted), the allowlist cache entries for their jtis are
  busted on every node, and a `"disconnect"` is broadcast on the user's
  socket id topic (the remote-lock signal — clients drop the DEK on it).
  Always returns `:ok`; an unknown token is a no-op.
  """
  def logout(refresh_token) when is_binary(refresh_token) do
    case Repo.get_by(RefreshToken, token: refresh_token) do
      nil -> :ok
      stored -> revoke_family(stored)
    end
  end

  def logout(_refresh_token), do: :ok

  defp revoke_family(%RefreshToken{} = stored) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    scope =
      if stored.family_id do
        dynamic([t], t.family_id == ^stored.family_id and is_nil(t.revoked_at))
      else
        # Pre-W4 rows have no family; revoke just the presented token's row.
        dynamic([t], t.id == ^stored.id and is_nil(t.revoked_at))
      end

    {_count, revoked_jtis} =
      from(t in RefreshToken, where: ^scope, select: t.jti)
      |> Repo.update_all(set: [revoked_at: now])

    Enum.each(revoked_jtis, &TokenAllowlist.invalidate/1)
    broadcast_session_disconnect(stored.user_id)
    :ok
  end

  # Remote-lock signal (W5 #1873, §9.3): `MatomeApiWeb.UserSocket.id/1` names
  # every socket of a user "user_socket:<id>", and Phoenix socket transports
  # terminate on a `"disconnect"` broadcast to that topic. Broadcast via
  # PubSub directly (this is exactly what `Endpoint.broadcast/3` does) so the
  # core Auth context does not reach into the web layer. Clients honor the
  # disconnect by dropping the in-memory DEK (client behavior, out of scope
  # here — see docs/token-revocation.md).
  defp broadcast_session_disconnect(user_id) do
    topic = "user_socket:#{user_id}"

    Phoenix.PubSub.broadcast(MatomeApi.PubSub, topic, %Phoenix.Socket.Broadcast{
      topic: topic,
      event: "disconnect",
      payload: %{}
    })
  end

  def verify_access_token(token) do
    with {:ok, claims} <- Guardian.decode_and_verify(token, %{"typ" => "access"}),
         {:ok, user} <- Guardian.resource_from_claims(claims) do
      {:ok, user, claims}
    else
      _ -> {:error, :unauthorized}
    end
  end

  @doc """
  Verifies a password-reset token (minted by `request_password_reset/1`) and
  resolves the user it was issued for. This is the pre-auth bootstrap task
  #1854 needs (CF-1, .docs/internal/at-rest-key-flow.md §5): a user who
  forgot their password has no session and so cannot hit the normal
  `:auth`-gated routes, but DOES have proof of email ownership via the reset
  token — which `MatomeApiWeb.Plugs.RequireResetToken` accepts in its place,
  scoped to only the `/keybundle/recovery` routes. Deliberately a separate
  function from `verify_access_token/1`: the `"typ"` claim check means an
  `access` token can never authenticate here and a `reset` token can never
  authenticate a normal `:auth`-gated route.
  """
  def verify_reset_token(token) do
    with {:ok, claims} <- Guardian.decode_and_verify(token, %{"typ" => "reset"}),
         {:ok, user} <- Guardian.resource_from_claims(claims) do
      {:ok, user, claims}
    else
      _ -> {:error, :invalid_reset_token}
    end
  end

  @doc "Returns the caller's key bundle, or `nil` if none has been stored yet."
  def get_key_bundle(%User{id: user_id}), do: Repo.get_by(KeyBundle, user_id: user_id)

  @doc """
  Upserts (PUT semantics) the caller's key bundle. Every field is an opaque,
  already-wrapped blob generated client-side — this function does not (and
  cannot) decode, verify, or derive anything from them; it is a passthrough
  store keyed on the unique `user_id` index, atomic via `on_conflict` rather
  than a read-then-write race.
  """
  def upsert_key_bundle(%User{id: user_id}, attrs) do
    attrs = Map.put(attrs, "user_id", user_id)

    %KeyBundle{}
    |> KeyBundle.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, KeyBundle.upsert_replace_fields()},
      conflict_target: :user_id,
      returning: true
    )
  end

  # Additive credential-shape support (task #1852, wave 2). A migrated client
  # never sends the raw password — it sends `auth_secret` (already Argon2id-
  # derived client-side under `salt_auth`) instead. An un-migrated client
  # still sends `password`. Both are just opaque strings from Core's point of
  # view, so accepting either param name here and folding it into the same
  # virtual `:password` cast field is enough to keep old clients from being
  # locked out while new clients stop transmitting the raw password.
  #
  # Subtractive follow-up (do not implement yet): once every client has
  # migrated, drop the `password` branch here (and its controller clause) so
  # registration only ever accepts `auth_secret` — a second breaking change,
  # tracked separately.
  defp normalize_credential(%{"auth_secret" => auth_secret} = attrs)
       when is_binary(auth_secret) do
    attrs |> Map.delete("auth_secret") |> Map.put("password", auth_secret)
  end

  defp normalize_credential(attrs), do: attrs

  defp with_tokens({:ok, user}, meta), do: issue_tokens(user, meta)
  defp with_tokens(error, _meta), do: error

  # The refresh token is minted FIRST so its jti (the session identifier —
  # the same value stored on the refresh_tokens row) can be embedded into the
  # access token as the `sid` claim. That binding is what lets W5 (#1873)
  # correlate every access token back to its session row for the per-request
  # revocation check without a second table.
  defp issue_tokens(user, meta) do
    with {:ok, refresh_token, refresh_claims} <-
           Guardian.encode_and_sign(user, %{}, token_type: "refresh", ttl: @refresh_ttl),
         {:ok, access_token, _access_claims} <-
           Guardian.encode_and_sign(user, %{"sid" => refresh_claims["jti"]},
             token_type: "access",
             ttl: @access_ttl
           ),
         {:ok, _stored_token} <- store_refresh_token(user, refresh_token, refresh_claims, meta) do
      {:ok, %{user: user, access_token: access_token, refresh_token: refresh_token}}
    end
  end

  defp store_refresh_token(user, token, %{"exp" => expires_at} = claims, meta) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    device = resolve_device(user, meta, now)

    %RefreshToken{}
    |> RefreshToken.changeset(%{
      token: token,
      user_id: user.id,
      expires_at: DateTime.from_unix!(expires_at),
      jti: claims["jti"],
      # A login starts a new token family; a refresh passes the inherited
      # family through `meta` (see `refresh/2`).
      family_id: Map.get(meta, :family_id) || Ecto.UUID.generate(),
      rotated_from: Map.get(meta, :rotated_from),
      device_id: device && device.id,
      ip: Map.get(meta, :ip),
      user_agent: Map.get(meta, :user_agent),
      login_method: Map.get(meta, :login_method),
      last_seen_at: now
    })
    |> Repo.insert()
  end

  # Resolves the device a token belongs to (W4 #1872).
  #
  # Refresh path: `meta.device_id` carries the device the family was minted
  # on — only its `last_seen_at` is touched, never re-correlated.
  defp resolve_device(_user, %{device_id: device_id}, now) when not is_nil(device_id) do
    case Repo.get(Device, device_id) do
      nil -> nil
      device -> device |> Ecto.Changeset.change(last_seen_at: now) |> Repo.update!()
    end
  end

  # Login path — correlation key, in order of preference:
  #   1. `(user_id, client_id)` when the client sent a stable `device.id`
  #      (upserted atomically on the unique index, so concurrent logins from
  #      the same device cannot duplicate);
  #   2. `(user_id, user_agent)` among NULL-client rows when it did not —
  #      weaker (a UA bump after an app update reads as a new device) but
  #      adds no identifier beyond what the request already carries;
  #   3. no user agent either ⇒ no device row (token keeps ip/ua only).
  defp resolve_device(user, meta, now) do
    device_params = Map.get(meta, :device) || %{}
    client_id = cast_uuid(device_params["id"])
    user_agent = Map.get(meta, :user_agent)

    cond do
      client_id != nil ->
        upsert_device(user, client_id, device_params, user_agent, now)

      is_binary(user_agent) ->
        correlate_device_by_user_agent(user, device_params, user_agent, now)

      true ->
        nil
    end
  end

  defp upsert_device(user, client_id, device_params, user_agent, now) do
    %Device{}
    |> Device.changeset(%{
      user_id: user.id,
      client_id: client_id,
      platform: device_params["platform"],
      display_name: device_params["display_name"],
      user_agent: user_agent,
      first_seen_at: now,
      last_seen_at: now
    })
    |> Repo.insert!(
      # On re-login the client-sent descriptor is authoritative for the
      # mutable fields; `first_seen_at`, `device_key_enrolled` and
      # `revoked_at` are deliberately NOT replaced.
      on_conflict:
        {:replace, [:platform, :display_name, :user_agent, :last_seen_at, :updated_at]},
      conflict_target: [:user_id, :client_id],
      returning: true
    )
  end

  defp correlate_device_by_user_agent(user, device_params, user_agent, now) do
    existing =
      Device
      |> where([d], d.user_id == ^user.id and is_nil(d.client_id) and d.user_agent == ^user_agent)
      |> limit(1)
      |> Repo.one()

    case existing do
      nil ->
        %Device{}
        |> Device.changeset(%{
          user_id: user.id,
          platform: device_params["platform"],
          display_name: device_params["display_name"],
          user_agent: user_agent,
          first_seen_at: now,
          last_seen_at: now
        })
        |> Repo.insert!()

      device ->
        device |> Ecto.Changeset.change(last_seen_at: now) |> Repo.update!()
    end
  end

  defp cast_uuid(value) do
    case Ecto.UUID.cast(value) do
      {:ok, uuid} -> uuid
      :error -> nil
    end
  end

  defp active_refresh_token(token) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    RefreshToken
    |> where(
      [refresh_token],
      refresh_token.token == ^token and refresh_token.expires_at > ^now and
        is_nil(refresh_token.revoked_at)
    )
    |> Repo.one()
  end
end
