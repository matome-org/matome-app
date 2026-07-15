defmodule MatomeApi.Admin do
  @moduledoc """
  Access control for the /admin back-office — email-OTP gate:

  - **Panel kill switch** — `ADMIN_PANEL_ENABLED` (see `NetworkPolicy`).
  - **Email allowlist** — `ADMIN_EMAIL_ALLOWLIST`; no `users` row required.
  - **One-shot email OTP** — hashed in `admin_login_otps`, 30-min TTL.
  - **Day-one audit** — `audit!/2` writes fail-closed security events.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias MatomeApi.Admin.{Dashboard, LoginOtp, NetworkPolicy, Notifier, TotpSecret}
  alias MatomeApi.Auth
  alias MatomeApi.Auth.{RefreshToken, User}
  alias MatomeApi.Content.{SpaceKeyWrap, SpaceLifecycleJob, SpaceMember, Workspace}
  alias MatomeApi.Events
  alias MatomeApi.Events.EventCatalog
  alias MatomeApi.RateLimiter
  alias MatomeApi.Repo
  alias MatomeApi.SystemConfig
  alias MatomeApi.SystemConfig.Reconciler

  @otp_ttl_seconds 30 * 60
  @otp_attempt_limit 5
  @otp_window_ms 60_000
  @otp_lockout_ms 300_000

  @doc "True when `email` is on the admin email allowlist."
  def email_allowed?(email), do: NetworkPolicy.email_allowed?(email)

  @doc "Activity window (seconds) for dashboard + Sessions “active recently”."
  def activity_window_seconds, do: Dashboard.activity_window_seconds()

  @doc "Landing dashboard aggregations with a mandatory sensitive-read event."
  def dashboard_stats(opts) when is_list(opts), do: dashboard_stats(DateTime.utc_now(), opts)

  def dashboard_stats(%DateTime{} = now, opts) when is_list(opts) do
    result = Dashboard.stats(now)
    audit_sensitive_read!("dashboard", opts)
    result
  end

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

      otp_changeset =
        LoginOtp.changeset(%LoginOtp{}, %{
          email: email,
          code_hash: hash_code(code),
          expires_at: expires_at,
          remote_ip: remote_ip && to_string(remote_ip)
        })

      event_attrs =
        audit_attrs("admin.login_otp_requested",
          actor: %{email: email},
          remote_ip: remote_ip && to_string(remote_ip)
        )

      Multi.new()
      |> Multi.update_all(
        :expire_previous,
        from(o in LoginOtp, where: o.email == ^email and is_nil(o.consumed_at)),
        set: [consumed_at: now]
      )
      |> Multi.insert(:otp, otp_changeset)
      |> Events.put_security(
        :event,
        event_key!("admin.login_otp_requested"),
        event_attrs
      )
      |> Repo.transaction()
      |> case do
        {:ok, _changes} ->
          case Notifier.deliver_login_otp(email, code) do
            {:ok, _} ->
              {:ok, :sent}

            {:error, reason} ->
              {:error, reason}
          end

        {:error, :event, changeset, _changes} ->
          {:error, {:audit_failed, changeset}}

        {:error, _operation, reason, _changes} ->
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
  def verify_login_otp(email, code, opts \\ []) do
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
          verify_and_consume_otp(email, code, now, opts)
      end
    end
  end

  defp generate_otp_code do
    1_000_000
    |> secure_uniform()
    |> Integer.to_string()
    |> String.pad_leading(6, "0")
  end

  defp secure_uniform(limit) do
    <<candidate::unsigned-32>> = :crypto.strong_rand_bytes(4)
    upper_bound = 4_294_967_296 - rem(4_294_967_296, limit)

    if candidate < upper_bound, do: rem(candidate, limit), else: secure_uniform(limit)
  end

  defp hash_code(code), do: :crypto.mac(:hmac, :sha256, otp_pepper(), code)

  defp otp_pepper do
    Application.fetch_env!(:matome_api, :admin_otp)
    |> Keyword.fetch!(:pepper)
  end

  defp verify_and_consume_otp(email, code, now, opts) do
    action = Keyword.get(opts, :audit_action, "admin.login")

    event_attrs =
      audit_attrs(action,
        actor: %{email: email},
        metadata: %{method: "email_otp", result: "verified"},
        remote_ip: Keyword.get(opts, :remote_ip)
      )

    Multi.new()
    |> Multi.run(:otp, fn repo, _changes ->
      otp =
        from(o in LoginOtp,
          where: o.email == ^email and is_nil(o.consumed_at) and o.expires_at > ^now,
          order_by: [desc: o.inserted_at],
          limit: 1,
          lock: "FOR UPDATE"
        )
        |> repo.one()

      if otp && secure_compare(otp.code_hash, hash_code(code)) do
        {:ok, otp}
      else
        {:error, :invalid_code}
      end
    end)
    |> Multi.update_all(
      :consume,
      fn %{otp: otp} -> from(o in LoginOtp, where: o.id == ^otp.id and is_nil(o.consumed_at)) end,
      set: [consumed_at: now]
    )
    |> Events.put_security(:event, event_key!(action), event_attrs)
    |> Repo.transaction()
    |> case do
      {:ok, %{consume: {1, _}}} -> {:ok, email}
      {:error, :otp, :invalid_code, _changes} -> {:error, :invalid_code}
      {:error, :event, changeset, _changes} -> {:error, {:audit_failed, changeset}}
      {:error, _operation, _reason, _changes} -> {:error, :invalid_code}
    end
  end

  defp secure_compare(a, b) when is_binary(a) and is_binary(b) and byte_size(a) == byte_size(b) do
    Plug.Crypto.secure_compare(a, b)
  end

  defp secure_compare(_, _), do: false

  defp normalize_email(email) when is_binary(email),
    do: email |> String.trim() |> String.downcase()

  defp normalize_email(_), do: ""

  @doc """
  The §9.2 sessions view data: every ACTIVE session grouped
  `user → device → tokens`.
  """
  def session_tree(opts) when is_list(opts), do: session_tree(DateTime.utc_now(), opts)

  def session_tree(%DateTime{} = now, opts) when is_list(opts) do
    result =
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

    audit_sensitive_read!("sessions", opts)
    result
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
    with {:ok, context} <- authorize_mutation(Keyword.put(opts, :actor, actor)) do
      Multi.new()
      |> Multi.run(:token, fn repo, _changes ->
        case repo.get_by(RefreshToken, [jti: jti], lock: "FOR UPDATE") do
          nil -> {:error, :not_found}
          token -> {:ok, token}
        end
      end)
      |> Multi.update_all(
        :revoke,
        fn %{token: token} ->
          scope =
            if token.family_id do
              dynamic([t], t.family_id == ^token.family_id and is_nil(t.revoked_at))
            else
              dynamic([t], t.id == ^token.id and is_nil(t.revoked_at))
            end

          from(t in RefreshToken, where: ^scope, select: t.jti)
        end,
        set: [revoked_at: DateTime.utc_now() |> DateTime.truncate(:second)]
      )
      |> Events.put_security(:event, event_key!("admin.session_revoked"), fn %{token: token} ->
        audit_attrs("admin.session_revoked",
          actor: context.actor,
          remote_ip: context.remote_ip,
          metadata: %{
            jti: jti,
            user_id: token.user_id,
            family_id: token.family_id,
            device_id: token.device_id,
            before: "active",
            after: "revoked"
          }
        )
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{token: token, revoke: {_count, revoked_jtis}}} ->
          :ok = Auth.notify_sessions_revoked(token.user_id, revoked_jtis)
          :ok

        {:error, :token, :not_found, _changes} ->
          {:error, :not_found}

        {:error, :event, changeset, _changes} ->
          {:error, {:audit_failed, changeset}}

        {:error, _operation, reason, _changes} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Appends a mandatory security event; raises on failure.

  `opts`: `:actor` (`%{email: ...}`, `%User{}`, or nil), `:metadata`, `:remote_ip`.
  """
  def audit!(action, opts \\ []) when is_binary(action) do
    Events.write_security!(event_key!(action), audit_attrs(action, opts))
  end

  defp audit_attrs(action, opts) do
    {actor_id, actor_email} = opts |> Keyword.get(:actor) |> actor_fields()

    action
    |> admin_event_attrs(Keyword.get(opts, :metadata, %{}))
    |> Map.merge(%{
      actor_id: actor_id,
      actor_email: actor_email,
      remote_ip: Keyword.get(opts, :remote_ip),
      severity: if(action == "admin.login_failed", do: "warning", else: "info")
    })
  end

  defp event_key!(action) do
    {:ok, event_key} = Events.admin_event_key(action)
    event_key
  end

  defp actor_fields(%User{id: id, email: email}), do: {id, email}
  defp actor_fields(%{email: email}) when is_binary(email), do: {nil, email}
  defp actor_fields(%{email: email}) when not is_nil(email), do: {nil, to_string(email)}
  defp actor_fields(_), do: {nil, nil}

  @doc """
  The §9.6 users directory: accounts with login methods, MFA status, last login.
  """
  def list_users(opts) when is_list(opts) do
    mfa_ids =
      from(t in TotpSecret, where: not is_nil(t.confirmed_at), select: t.user_id)
      |> Repo.all()
      |> MapSet.new()

    tokens_by_user =
      from(t in RefreshToken, order_by: [desc: t.last_seen_at])
      |> Repo.all()
      |> Enum.group_by(& &1.user_id)

    result =
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

    audit_sensitive_read!("users", opts)
    result
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
  Read security-class events for the existing admin audit view, newest first.
  """
  def list_audit_events(opts \\ []) do
    actor_id = Keyword.get(opts, :actor_id)
    actor_email = blank_to_nil(Keyword.get(opts, :actor_email))
    action = blank_to_nil(Keyword.get(opts, :action))
    target = blank_to_nil(Keyword.get(opts, :target))
    since = Keyword.get(opts, :since)
    until = Keyword.get(opts, :until)

    event_key =
      case action && Events.admin_event_key(action) do
        {:ok, key} -> key
        _other -> action
      end

    result =
      [
        limit: 100,
        event_class: "security",
        actor_id: actor_id,
        actor_email: actor_email && String.downcase(actor_email),
        event_key: event_key,
        since: since,
        until: until
      ]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Events.list_events()
      |> Map.fetch!(:entries)
      |> maybe_filter_target(target)

    audit_sensitive_read!("audit", opts)
    result
  end

  @doc "Reads one bounded event-timeline page and records the sensitive admin read."
  def list_events(event_opts, audit_opts) when is_list(event_opts) and is_list(audit_opts) do
    page = Events.list_events(event_opts)
    audit_sensitive_read!("events", audit_opts)
    page
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: value

  defp maybe_filter_target(events, nil), do: events

  defp maybe_filter_target(events, target) do
    needle = String.downcase(target)

    Enum.filter(events, fn event ->
      subject_matches? =
        event.subject_id && String.contains?(String.downcase(event.subject_id), needle)

      owner_matches? = event.owner_id && String.contains?(to_string(event.owner_id), needle)

      details_match? =
        event.details
        |> Jason.encode!()
        |> String.downcase()
        |> String.contains?(needle)

      subject_matches? || owner_matches? || details_match?
    end)
  end

  defp admin_event_attrs(action, metadata) do
    metadata = stringify_keys(metadata)

    case action do
      "admin.session_revoked" ->
        %{details: Map.take(metadata, ~w(before after))}
        |> put_present(:owner_id, metadata["user_id"])
        |> put_present(:device_id, metadata["device_id"])
        |> put_present(:correlation_id, metadata["family_id"])
        |> put_subject("session", metadata["jti"])

      "admin.space_updated" ->
        changed_keys =
          metadata
          |> Map.get("changes", %{})
          |> Map.keys()
          |> Enum.map(&to_string/1)
          |> Enum.sort()

        %{}
        |> put_subject("workspace", metadata["workspace_id"])
        |> Map.put(
          :details,
          metadata |> Map.take(~w(before after)) |> Map.put("changed_keys", changed_keys)
        )

      "admin.space_member_added" ->
        %{
          details: Map.take(metadata, ~w(workspace_id user_id role before after))
        }
        |> put_subject("space_member", metadata["member_id"])

      "admin.space_member_revoked" ->
        %{
          details: Map.take(metadata, ~w(workspace_id user_id before after))
        }
        |> put_subject("space_member", metadata["member_id"])

      "admin.space_lifecycle" ->
        %{details: Map.take(metadata, ~w(before after))}
        |> put_subject("workspace", metadata["workspace_id"])

      "admin.sensitive_read" ->
        %{details: Map.take(metadata, ~w(resource result))}
        |> put_subject(metadata["subject_type"] || "admin_view", metadata["subject_id"])

      "admin.login" ->
        %{details: Map.take(metadata, ~w(method result via))}

      "admin.login_failed" ->
        %{details: Map.take(metadata, ~w(method reason result))}

      "admin.reauth" ->
        %{details: Map.take(metadata, ~w(method result))}

      _other ->
        %{details: %{}}
    end
  end

  defp stringify_keys(metadata) when is_map(metadata) do
    Map.new(metadata, fn {key, value} -> {to_string(key), value} end)
  end

  defp stringify_keys(_metadata), do: %{}

  defp put_present(attrs, _key, nil), do: attrs
  defp put_present(attrs, key, value), do: Map.put(attrs, key, value)

  defp put_subject(attrs, _type, nil), do: attrs

  defp put_subject(attrs, type, id) do
    attrs
    |> Map.put(:subject_type, type)
    |> Map.put(:subject_id, to_string(id))
  end

  @doc """
  §9.4 Spaces directory for the admin LiveView — every workspace with owner
  email, two-axis fields, quota/lifecycle, and active member count.
  """
  def list_spaces(opts) when is_list(opts) do
    member_counts =
      from(m in SpaceMember,
        where: is_nil(m.revoked_at),
        group_by: m.workspace_id,
        select: {m.workspace_id, count(m.id)}
      )
      |> Repo.all()
      |> Map.new()

    result =
      from(w in Workspace,
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

    audit_sensitive_read!("spaces", opts)
    result
  end

  def get_space(id, opts) when is_list(opts) do
    workspace = get_space_raw(id)
    audit_sensitive_read!("space", opts, "workspace", id)
    workspace
  end

  defp get_space_raw(id) do
    case Repo.get(Workspace, id) do
      nil ->
        nil

      workspace ->
        workspace
        |> Repo.preload([:owner, space_members: :user])
    end
  end

  def update_space(id, attrs, opts \\ []) do
    with {:ok, context} <- authorize_mutation(opts) do
      Multi.new()
      |> Multi.run(:workspace, fn repo, _changes ->
        case repo.get(Workspace, id, lock: "FOR UPDATE") do
          nil -> {:error, :not_found}
          workspace -> {:ok, workspace}
        end
      end)
      |> Multi.update(:updated, fn %{workspace: workspace} ->
        Workspace.admin_changeset(workspace, attrs)
      end)
      |> Events.put_security(:event, event_key!("admin.space_updated"), fn %{
                                                                             workspace: before,
                                                                             updated: after_state
                                                                           } ->
        before_snapshot = space_policy_snapshot(before)
        after_snapshot = space_policy_snapshot(after_state)

        changes =
          before_snapshot
          |> Map.keys()
          |> Enum.filter(&(before_snapshot[&1] != after_snapshot[&1]))
          |> Map.new(&{&1, after_snapshot[&1]})

        audit_attrs("admin.space_updated",
          actor: context.actor,
          remote_ip: context.remote_ip,
          metadata: %{
            workspace_id: id,
            changes: changes,
            before: Jason.encode!(before_snapshot),
            after: Jason.encode!(after_snapshot)
          }
        )
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{updated: updated}} ->
          {:ok, Repo.preload(updated, [:owner, space_members: :user], force: true)}

        {:error, :event, changeset, _changes} ->
          {:error, {:audit_failed, changeset}}

        {:error, _operation, reason, _changes} ->
          {:error, reason}
      end
    end
  end

  def add_space_member(workspace_id, user_id, role, opts \\ []) do
    with {:ok, context} <- authorize_mutation(opts) do
      member_changeset =
        SpaceMember.changeset(%SpaceMember{}, %{
          workspace_id: workspace_id,
          user_id: user_id,
          role: role,
          granted_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      Multi.new()
      |> Multi.insert(:member, member_changeset)
      |> Events.put_security(:event, event_key!("admin.space_member_added"), fn %{member: member} ->
        audit_attrs("admin.space_member_added",
          actor: context.actor,
          remote_ip: context.remote_ip,
          metadata: %{
            workspace_id: workspace_id,
            user_id: user_id,
            member_id: member.id,
            role: role,
            before: "absent",
            after: role
          }
        )
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{member: member}} -> {:ok, Repo.preload(member, :user)}
        {:error, :event, changeset, _changes} -> {:error, {:audit_failed, changeset}}
        {:error, _operation, reason, _changes} -> {:error, reason}
      end
    end
  end

  def revoke_space_member(member_id, opts \\ []) do
    with {:ok, context} <- authorize_mutation(opts) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Multi.new()
      |> Multi.run(:member, fn repo, _changes ->
        case repo.get(SpaceMember, member_id, lock: "FOR UPDATE") do
          nil -> {:error, :not_found}
          %SpaceMember{revoked_at: %DateTime{}} -> {:error, :already_revoked}
          member -> {:ok, member}
        end
      end)
      |> Multi.update(:updated, fn %{member: member} ->
        Ecto.Changeset.change(member, revoked_at: now)
      end)
      |> Multi.update_all(
        :key_wraps,
        fn %{member: member} ->
          from(w in SpaceKeyWrap,
            where: w.workspace_id == ^member.workspace_id,
            where: w.user_id == ^member.user_id,
            where: is_nil(w.revoked_at)
          )
        end,
        set: [revoked_at: now]
      )
      |> Events.put_security(:event, event_key!("admin.space_member_revoked"), fn %{
                                                                                    member: member
                                                                                  } ->
        audit_attrs("admin.space_member_revoked",
          actor: context.actor,
          remote_ip: context.remote_ip,
          metadata: %{
            workspace_id: member.workspace_id,
            user_id: member.user_id,
            member_id: member.id,
            before: member.role,
            after: "revoked"
          }
        )
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{updated: updated}} -> {:ok, updated}
        {:error, :event, changeset, _changes} -> {:error, {:audit_failed, changeset}}
        {:error, _operation, reason, _changes} -> {:error, reason}
      end
    end
  end

  def transition_space(workspace_id, to_status, opts \\ []) do
    with {:ok, context} <- authorize_mutation(opts) do
      Multi.new()
      |> Multi.run(:workspace, fn repo, _changes ->
        case repo.get(Workspace, workspace_id, lock: "FOR UPDATE") do
          nil -> {:error, :not_found}
          workspace -> {:ok, workspace}
        end
      end)
      |> Multi.run(:transition, fn _repo, %{workspace: workspace} ->
        SpaceLifecycleJob.transition_changeset(workspace, to_status)
      end)
      |> Multi.update(:updated, fn %{transition: changeset} -> changeset end)
      |> Events.put_security(:event, event_key!("admin.space_lifecycle"), fn %{
                                                                               workspace: before,
                                                                               updated:
                                                                                 after_state
                                                                             } ->
        audit_attrs("admin.space_lifecycle",
          actor: context.actor,
          remote_ip: context.remote_ip,
          metadata: %{
            workspace_id: workspace_id,
            before: before.status,
            after: after_state.status
          }
        )
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{updated: updated}} ->
          {:ok, Repo.preload(updated, [:owner, space_members: :user], force: true)}

        {:error, :event, changeset, _changes} ->
          {:error, {:audit_failed, changeset}}

        {:error, _operation, reason, _changes} ->
          {:error, reason}
      end
    end
  end

  @doc "Secure seam for future event-collection configuration controls."
  def update_event_catalog(key, attrs, opts \\ []) when is_binary(key) and is_map(attrs) do
    with {:ok, context} <- authorize_mutation(opts) do
      Multi.new()
      |> Multi.run(:catalog, fn repo, _changes ->
        case repo.get(EventCatalog, key, lock: "FOR UPDATE") do
          nil -> {:error, :not_found}
          %EventCatalog{locked: true} -> {:error, :locked}
          catalog -> {:ok, catalog}
        end
      end)
      |> Multi.update(:updated, fn %{catalog: catalog} ->
        changeset = EventCatalog.changeset(catalog, attrs)

        if changeset.changes == %{} do
          Ecto.Changeset.add_error(changeset, :base, "must change at least one field")
        else
          changeset
        end
      end)
      |> Events.put_security(:event, "security.event_catalog.changed.v2", fn %{
                                                                               catalog: before,
                                                                               updated:
                                                                                 after_state
                                                                             } ->
        {actor_id, actor_email} = actor_fields(context.actor)

        changed_fields =
          [:enabled, :description, :retention_days]
          |> Enum.filter(&(Map.get(before, &1) != Map.get(after_state, &1)))
          |> Enum.map(&to_string/1)

        %{
          actor_id: actor_id,
          actor_email: actor_email,
          remote_ip: context.remote_ip,
          subject_type: "event_catalog",
          subject_id: key,
          details: %{
            changed_fields: changed_fields,
            before: Jason.encode!(catalog_policy_snapshot(before)),
            after: Jason.encode!(catalog_policy_snapshot(after_state)),
            result: "updated"
          }
        }
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{updated: updated}} -> {:ok, updated}
        {:error, :event, changeset, _changes} -> {:error, {:audit_failed, changeset}}
        {:error, _operation, reason, _changes} -> {:error, reason}
      end
    end
  end

  @doc "Update the global non-secret policy through allowlist, recent OTP, CAS, and audit gates."
  def update_system_config(desired, base_revision, opts \\ [])
      when is_map(desired) and is_integer(base_revision) do
    with {:ok, context} <- authorize_mutation(opts) do
      case SystemConfig.update_desired(desired, base_revision, context) do
        {:ok, _config} = result ->
          Reconciler.reconcile_async()
          result

        error ->
          error
      end
    end
  end

  defp authorize_mutation(opts) do
    with {:ok, actor} <- authorize_actor(Keyword.get(opts, :actor)),
         {:otp, otp_at} when is_integer(otp_at) <-
           {:otp, Keyword.get(opts, :otp_verified_at)},
         true <- recent_otp?(otp_at),
         remote_ip when is_binary(remote_ip) and remote_ip != "" <- Keyword.get(opts, :remote_ip) do
      {:ok, %{actor: actor, remote_ip: remote_ip}}
    else
      {:error, reason} -> {:error, reason}
      {:otp, _otp_at} -> {:error, :recent_otp_required}
      false -> {:error, :recent_otp_required}
      _ -> {:error, :invalid_client_ip}
    end
  end

  defp authorize_actor(%User{email: email} = actor) do
    if email_allowed?(email), do: {:ok, actor}, else: {:error, :forbidden}
  end

  defp authorize_actor(%{email: email}) when is_binary(email) do
    email = normalize_email(email)
    if email_allowed?(email), do: {:ok, %{email: email}}, else: {:error, :forbidden}
  end

  defp authorize_actor(_actor), do: {:error, :forbidden}

  defp recent_otp?(verified_at) do
    now = System.os_time(:second)

    ttl =
      Application.get_env(:matome_api, :admin_session, [])
      |> Keyword.get(:reauth_ttl_seconds, 5 * 60)

    verified_at <= now and now < verified_at + ttl
  end

  defp audit_sensitive_read!(resource, opts, subject_type \\ "admin_view", subject_id \\ nil) do
    actor = Keyword.get(opts, :actor)
    remote_ip = Keyword.get(opts, :remote_ip)

    with {:ok, actor} <- authorize_actor(actor),
         true <- is_binary(remote_ip) and remote_ip != "" do
      audit!("admin.sensitive_read",
        actor: actor,
        remote_ip: remote_ip,
        metadata: %{
          resource: resource,
          result: "success",
          subject_type: subject_type,
          subject_id: subject_id || resource
        }
      )
    else
      _ -> raise "sensitive admin read denied"
    end
  end

  defp space_policy_snapshot(workspace) do
    %{
      "quota_bytes" => workspace.quota_bytes,
      "expires_at" => workspace.expires_at && DateTime.to_iso8601(workspace.expires_at),
      "status" => workspace.status,
      "space_type" => workspace.space_type,
      "is_local" => workspace.is_local
    }
  end

  defp catalog_policy_snapshot(catalog) do
    %{
      "enabled" => catalog.enabled,
      "retention_days" => catalog.retention_days
    }
  end
end
