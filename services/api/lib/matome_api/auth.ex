defmodule MatomeApi.Auth do
  import Ecto.Query

  alias MatomeApi.Auth.{Guardian, KeyBundle, RefreshToken, User}
  alias MatomeApi.Repo

  @access_ttl {15, :minutes}
  @refresh_ttl {30, :days}
  @reset_ttl {30, :minutes}

  def get_user(id), do: Repo.get(User, id)

  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(normalize_credential(attrs))
    |> Repo.insert()
    |> with_tokens()
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
  def login(email, credential) do
    user = Repo.get_by(User, email: String.downcase(email || ""))

    cond do
      user && Argon2.verify_pass(credential || "", user.password_hash) ->
        with_tokens({:ok, user})

      true ->
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
  def reset_password(token, new_password) do
    with {:ok, claims} <- Guardian.decode_and_verify(token, %{"typ" => "reset"}),
         {:ok, %User{} = user} <- Guardian.resource_from_claims(claims),
         {:ok, updated} <-
           user
           |> User.password_update_changeset(%{password: new_password})
           |> Repo.update() do
      Repo.delete_all(from(t in RefreshToken, where: t.user_id == ^updated.id))
      issue_tokens(updated)
    else
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
      _ -> {:error, :invalid_reset_token}
    end
  end

  def refresh(refresh_token) when is_binary(refresh_token) do
    with {:ok, claims} <- Guardian.decode_and_verify(refresh_token, %{"typ" => "refresh"}),
         %RefreshToken{} = stored <- active_refresh_token(refresh_token),
         {:ok, user} <- Guardian.resource_from_claims(claims) do
      Repo.delete!(stored)
      issue_tokens(user)
    else
      _ -> {:error, :invalid_refresh_token}
    end
  end

  def refresh(_refresh_token), do: {:error, :invalid_refresh_token}

  def logout(refresh_token) when is_binary(refresh_token) do
    from(token in RefreshToken, where: token.token == ^refresh_token)
    |> Repo.delete_all()

    :ok
  end

  def logout(_refresh_token), do: :ok

  def verify_access_token(token) do
    with {:ok, claims} <- Guardian.decode_and_verify(token, %{"typ" => "access"}),
         {:ok, user} <- Guardian.resource_from_claims(claims) do
      {:ok, user, claims}
    else
      _ -> {:error, :unauthorized}
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

  defp with_tokens({:ok, user}), do: issue_tokens(user)
  defp with_tokens(error), do: error

  defp issue_tokens(user) do
    with {:ok, access_token, _access_claims} <-
           Guardian.encode_and_sign(user, %{}, token_type: "access", ttl: @access_ttl),
         {:ok, refresh_token, refresh_claims} <-
           Guardian.encode_and_sign(user, %{}, token_type: "refresh", ttl: @refresh_ttl),
         {:ok, _stored_token} <- store_refresh_token(user, refresh_token, refresh_claims) do
      {:ok, %{user: user, access_token: access_token, refresh_token: refresh_token}}
    end
  end

  defp store_refresh_token(user, token, %{"exp" => expires_at}) do
    %RefreshToken{}
    |> RefreshToken.changeset(%{
      token: token,
      user_id: user.id,
      expires_at: DateTime.from_unix!(expires_at)
    })
    |> Repo.insert()
  end

  defp active_refresh_token(token) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    RefreshToken
    |> where([refresh_token], refresh_token.token == ^token and refresh_token.expires_at > ^now)
    |> Repo.one()
  end
end
