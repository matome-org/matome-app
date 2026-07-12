defmodule MatomeApi.Admin do
  @moduledoc """
  Access control for the /admin back-office — email-OTP gate:

  - **Panel kill switch** — `ADMIN_PANEL_ENABLED` (see `NetworkPolicy`).
  - **Email allowlist** — `ADMIN_EMAIL_ALLOWLIST`; no `users` row required.
  - **One-shot email OTP** — hashed in `admin_login_otps`, 30-min TTL.
  - **Day-one audit** — `audit!/2` writes append-only `admin_audit_events`.
  """

  import Ecto.Query

  alias MatomeApi.Admin.{AuditEvent, Dashboard, LoginOtp, NetworkPolicy, Notifier, TotpSecret}
  alias MatomeApi.Auth
  alias MatomeApi.Auth.{RefreshToken, User}
  alias MatomeApi.RateLimiter
  alias MatomeApi.Repo

  @otp_ttl_seconds 30 * 60
  @otp_attempt_limit 5
  @otp_window_ms 60_000
  @otp_lockout_ms 300_000

  @doc "True when `email` is on the admin email allowlist."
  def email_allowed?(email), do: NetworkPolicy.email_allowed?(email)

  @doc "Activity window (seconds) for dashboard + Sessions “active recently”."
  def activity_window_seconds, do: Dashboard.activity_window_seconds()

  @doc "Landing dashboard aggregations — see `MatomeApi.Admin.Dashboard.stats/1`."
  def dashboard_stats(now \\ DateTime.utc_now()), do: Dashboard.stats(now)

  @doc """
  Request a login OTP for an allowlisted email.

  Returns:
  - `{:ok, :sent}` when the email is allowlisted and delivery succeeded
  - `:silent` when the email is not allowlisted (caller must not reveal this)
  - `{:error, reason}` on delivery/storage failure for an allowlisted email
  """
  def request_login_otp(email, opts \\ []) do
    email = normalize_email(email)
    remote_ip = Keyword.get(opts, :remote_ip)

    if email_allowed?(email) do
      code = generate_otp_code()
      now = DateTime.utc_now()
      expires_at = DateTime.add(now, @otp_ttl_seconds, :second)

      Repo.transaction(fn ->
        from(o in LoginOtp, where: o.email == ^email and is_nil(o.consumed_at))
        |> Repo.update_all(set: [consumed_at: now])

        %LoginOtp{}
        |> LoginOtp.changeset(%{
          email: email,
          code_hash: hash_code(code),
          expires_at: expires_at,
          remote_ip: remote_ip && to_string(remote_ip)
        })
        |> Repo.insert!()
      end)
      |> case do
        {:ok, _} ->
          case Notifier.deliver_login_otp(email, code) do
            {:ok, _} ->
              audit!("admin.login_otp_requested",
                actor: %{email: email},
                remote_ip: remote_ip && to_string(remote_ip)
              )

              {:ok, :sent}

            {:error, reason} ->
              {:error, reason}
          end

        {:error, reason} ->
          {:error, reason}
      end
    else
      :silent
    end
  end

  @doc """
  Verify a one-shot login OTP. Returns `{:ok, email}`, `{:error, :invalid_code}`,
  or `{:error, :rate_limited}`.
  """
  def verify_login_otp(email, code, _opts \\ []) do
    email = normalize_email(email)
    code = String.trim(code || "")
    now = DateTime.utc_now()

    unless email_allowed?(email) do
      {:error, :invalid_code}
    else
      case RateLimiter.check(
             {:admin_otp, email},
             @otp_attempt_limit,
             @otp_window_ms,
             @otp_lockout_ms
           ) do
        {:error, :locked} ->
          {:error, :rate_limited}

        :ok ->
          otp =
            from(o in LoginOtp,
              where:
                o.email == ^email and is_nil(o.consumed_at) and o.expires_at > ^now,
              order_by: [desc: o.inserted_at],
              limit: 1
            )
            |> Repo.one()

          cond do
            is_nil(otp) ->
              {:error, :invalid_code}

            not secure_compare(otp.code_hash, hash_code(code)) ->
              {:error, :invalid_code}

            true ->
              {1, _} =
                from(o in LoginOtp, where: o.id == ^otp.id and is_nil(o.consumed_at))
                |> Repo.update_all(set: [consumed_at: now])

              {:ok, email}
          end
      end
    end
  end

  defp generate_otp_code do
    0..5
    |> Enum.map(fn _ -> Integer.to_string(:rand.uniform(10) - 1) end)
    |> Enum.join()
  end

  defp hash_code(code), do: :crypto.hash(:sha256, code)

  defp secure_compare(a, b) when is_binary(a) and is_binary(b) and byte_size(a) == byte_size(b) do
    Plug.Crypto.secure_compare(a, b)
  end

  defp secure_compare(_, _), do: false

  defp normalize_email(email) when is_binary(email), do: email |> String.trim() |> String.downcase()
  defp normalize_email(_), do: ""

  @doc """
  The §9.2 sessions view data: every ACTIVE session grouped
  `user → device → tokens`.
  """
  def session_tree(now \\ DateTime.utc_now()) do
    from(t in RefreshToken,
      where: is_nil(t.revoked_at) and t.expires_at > ^now,
      order_by: [desc: t.last_seen_at],
      preload: [:user, :device]
    )
    |> Repo.all()
    |> Enum.group_by(& &1.user_id)
    |> Enum.map(fn {_user_id, [first | _] = tokens} ->
      %{
        user: first.user,
        last_seen_at: most_recent(tokens),
        devices: group_by_device(tokens)
      }
    end)
    |> Enum.sort_by(& &1.last_seen_at, {:desc, DateTime})
  end

  defp group_by_device(tokens) do
    tokens
    |> Enum.group_by(& &1.device_id)
    |> Enum.map(fn {_device_id, [first | _] = device_tokens} ->
      %{device: first.device, tokens: device_tokens, last_seen_at: most_recent(device_tokens)}
    end)
    |> Enum.sort_by(& &1.last_seen_at, {:desc, DateTime})
  end

  defp most_recent(tokens) do
    tokens
    |> Enum.map(&(&1.last_seen_at || &1.inserted_at))
    |> Enum.max(DateTime)
  end

  @doc """
  Administrative session revocation. `actor` is `%{email: ...}` (or a User).
  """
  def revoke_session(actor, jti, opts \\ []) when is_binary(jti) do
    case Repo.get_by(RefreshToken, jti: jti) do
      nil ->
        {:error, :not_found}

      %RefreshToken{} = token ->
        :ok = Auth.revoke_session(token)

        audit!("admin.session_revoked",
          actor: actor,
          metadata: %{
            "jti" => jti,
            "user_id" => token.user_id,
            "family_id" => token.family_id,
            "device_id" => token.device_id
          },
          remote_ip: Keyword.get(opts, :remote_ip)
        )

        :ok
    end
  end

  @doc """
  Appends an admin audit event; raises on failure.

  `opts`: `:actor` (`%{email: ...}`, `%User{}`, or nil), `:metadata`, `:remote_ip`.
  """
  def audit!(action, opts \\ []) when is_binary(action) do
    actor = Keyword.get(opts, :actor)
    {actor_id, actor_email} = actor_fields(actor)

    %AuditEvent{}
    |> AuditEvent.changeset(%{
      actor_id: actor_id,
      actor_email: actor_email,
      action: action,
      metadata: Keyword.get(opts, :metadata, %{}),
      remote_ip: Keyword.get(opts, :remote_ip)
    })
    |> Repo.insert!()
  end

  defp actor_fields(%User{id: id, email: email}), do: {id, email}
  defp actor_fields(%{email: email}) when is_binary(email), do: {nil, email}
  defp actor_fields(%{email: email}) when not is_nil(email), do: {nil, to_string(email)}
  defp actor_fields(_), do: {nil, nil}

  @doc """
  The §9.6 users directory: accounts with login methods, MFA status, last login.
  """
  def list_users do
    mfa_ids =
      from(t in TotpSecret, where: not is_nil(t.confirmed_at), select: t.user_id)
      |> Repo.all()
      |> MapSet.new()

    tokens_by_user =
      from(t in RefreshToken, order_by: [desc: t.last_seen_at])
      |> Repo.all()
      |> Enum.group_by(& &1.user_id)

    from(u in User, order_by: [asc: u.email])
    |> Repo.all()
    |> Enum.map(fn user ->
      tokens = Map.get(tokens_by_user, user.id, [])

      %{
        user: user,
        login_methods: distinct_login_methods(tokens),
        mfa_enabled: MapSet.member?(mfa_ids, user.id),
        last_login_at: most_recent_or_nil(tokens)
      }
    end)
    |> Enum.sort_by(& &1.last_login_at, {:desc, DateTime})
  end

  defp distinct_login_methods(tokens) do
    tokens
    |> Enum.map(& &1.login_method)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp most_recent_or_nil([]), do: nil

  defp most_recent_or_nil(tokens) do
    tokens
    |> Enum.map(&(&1.last_seen_at || &1.inserted_at))
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      times -> Enum.max(times, DateTime)
    end
  end

  @doc """
  Read the append-only `admin_audit_events` trail, newest first.
  """
  def list_audit_events(opts \\ []) do
    actor_id = Keyword.get(opts, :actor_id)
    actor_email = blank_to_nil(Keyword.get(opts, :actor_email))
    action = blank_to_nil(Keyword.get(opts, :action))
    target = blank_to_nil(Keyword.get(opts, :target))
    since = Keyword.get(opts, :since)
    until = Keyword.get(opts, :until)

    from(e in AuditEvent, order_by: [desc: e.inserted_at])
    |> maybe_where_actor(actor_id)
    |> maybe_where_actor_email(actor_email)
    |> maybe_where_action(action)
    |> maybe_where_since(since)
    |> maybe_where_until(until)
    |> Repo.all()
    |> maybe_filter_target(target)
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: value

  defp maybe_where_actor(query, nil), do: query
  defp maybe_where_actor(query, actor_id), do: where(query, [e], e.actor_id == ^actor_id)

  defp maybe_where_actor_email(query, nil), do: query

  defp maybe_where_actor_email(query, email),
    do: where(query, [e], e.actor_email == ^String.downcase(email))

  defp maybe_where_action(query, nil), do: query
  defp maybe_where_action(query, action), do: where(query, [e], e.action == ^action)

  defp maybe_where_since(query, nil), do: query
  defp maybe_where_since(query, since), do: where(query, [e], e.inserted_at >= ^since)

  defp maybe_where_until(query, nil), do: query
  defp maybe_where_until(query, until), do: where(query, [e], e.inserted_at < ^until)

  defp maybe_filter_target(events, nil), do: events

  defp maybe_filter_target(events, target) do
    needle = String.downcase(target)

    Enum.filter(events, fn event ->
      event.metadata
      |> Jason.encode!()
      |> String.downcase()
      |> String.contains?(needle)
    end)
  end

  @doc """
  §9.4 Spaces directory for the admin LiveView — every workspace with owner
  email, two-axis fields, quota/lifecycle, and active member count.
  """
  def list_spaces do
    member_counts =
      from(m in MatomeApi.Content.SpaceMember,
        where: is_nil(m.revoked_at),
        group_by: m.workspace_id,
        select: {m.workspace_id, count(m.id)}
      )
      |> Repo.all()
      |> Map.new()

    from(w in MatomeApi.Content.Workspace,
      join: u in assoc(w, :owner),
      order_by: [asc: w.name],
      preload: [owner: u]
    )
    |> Repo.all()
    |> Enum.map(fn workspace ->
      %{
        workspace: workspace,
        owner_email: workspace.owner.email,
        member_count: Map.get(member_counts, workspace.id, 0)
      }
    end)
  end

  def get_space(id) do
    case Repo.get(MatomeApi.Content.Workspace, id) do
      nil ->
        nil

      workspace ->
        workspace
        |> Repo.preload([:owner, space_members: :user])
    end
  end

  def update_space(id, attrs, opts \\ []) do
    with %MatomeApi.Content.Workspace{} = workspace <- get_space(id) do
      workspace
      |> MatomeApi.Content.Workspace.admin_changeset(attrs)
      |> Repo.update()
      |> case do
        {:ok, updated} ->
          audit!("admin.space_updated",
            actor: Keyword.get(opts, :actor),
            remote_ip: Keyword.get(opts, :remote_ip),
            metadata: %{
              workspace_id: updated.id,
              changes: Map.take(attrs, ~w(quota_bytes expires_at status space_type is_local)a)
            }
          )

          {:ok, Repo.preload(updated, [:owner, space_members: :user], force: true)}

        other ->
          other
      end
    end
  end

  def add_space_member(workspace_id, user_id, role, opts \\ []) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %MatomeApi.Content.SpaceMember{}
    |> MatomeApi.Content.SpaceMember.changeset(%{
      workspace_id: workspace_id,
      user_id: user_id,
      role: role,
      granted_at: now
    })
    |> Repo.insert()
    |> case do
      {:ok, member} ->
        audit!("admin.space_member_added",
          actor: Keyword.get(opts, :actor),
          remote_ip: Keyword.get(opts, :remote_ip),
          metadata: %{workspace_id: workspace_id, user_id: user_id, role: role}
        )

        {:ok, Repo.preload(member, :user)}

      other ->
        other
    end
  end

  def revoke_space_member(member_id, opts \\ []) do
    case Repo.get(MatomeApi.Content.SpaceMember, member_id) do
      nil ->
        nil

      member ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        Repo.transaction(fn ->
          {:ok, updated} =
            member
            |> Ecto.Changeset.change(revoked_at: now)
            |> Repo.update()

          from(w in MatomeApi.Content.SpaceKeyWrap,
            where: w.workspace_id == ^updated.workspace_id,
            where: w.user_id == ^updated.user_id,
            where: is_nil(w.revoked_at)
          )
          |> Repo.update_all(set: [revoked_at: now])

          audit!("admin.space_member_revoked",
            actor: Keyword.get(opts, :actor),
            remote_ip: Keyword.get(opts, :remote_ip),
            metadata: %{
              workspace_id: updated.workspace_id,
              user_id: updated.user_id,
              member_id: updated.id
            }
          )

          updated
        end)
        |> case do
          {:ok, updated} -> {:ok, updated}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  def transition_space(workspace_id, to_status, opts \\ []) do
    case MatomeApi.Content.SpaceLifecycleJob.transition(workspace_id, to_status) do
      :ok ->
        audit!("admin.space_lifecycle",
          actor: Keyword.get(opts, :actor),
          remote_ip: Keyword.get(opts, :remote_ip),
          metadata: %{workspace_id: workspace_id, to_status: to_status}
        )

        {:ok, get_space(workspace_id)}

      {:discard, reason} ->
        {:error, reason}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
