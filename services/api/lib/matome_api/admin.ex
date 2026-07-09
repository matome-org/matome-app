defmodule MatomeApi.Admin do
  @moduledoc """
  Access control for the /admin back-office (W3 #1871, plan
  p2-core-backoffice §9.1) — the context behind the defense-in-depth gate:

  - **Hard role allowlist** — `users.role` in `admin|superadmin`. No signup
    or API path assigns a privileged role; provisioning is out-of-band.
  - **Mandatory TOTP** — enrollment (secret encrypted at rest via
    `SecretVault`) + verification with replay rejection (per-secret timestep
    high-water mark, claimed atomically) and attempt lockout (existing
    `MatomeApi.RateLimiter`: #{5} attempts / 60s, 5-min lockout).
  - **Day-one audit** — `audit!/2` writes to the DB-level append-only
    `admin_audit_events`; it raises on failure so an admin action can never
    silently proceed unaudited.
  """

  import Ecto.Query

  alias MatomeApi.Admin.{AuditEvent, SecretVault, TOTP, TotpSecret}
  alias MatomeApi.Auth.User
  alias MatomeApi.RateLimiter
  alias MatomeApi.Repo

  @admin_roles ~w(admin superadmin)

  # TOTP attempt lockout: more than @totp_attempt_limit attempts inside
  # @totp_window_ms locks the user out for @totp_lockout_ms.
  @totp_attempt_limit 5
  @totp_window_ms 60_000
  @totp_lockout_ms 300_000

  @doc "True when the user's role is on the admin allowlist."
  def admin?(%User{role: role}), do: role in @admin_roles
  def admin?(_), do: false

  @doc """
  First factor of the admin login: email + password, AND the role allowlist.

  Returns `{:error, :invalid_credentials}` for a wrong password, an unknown
  email, and a correct password on a NON-admin account alike — the response
  must not be an oracle for which accounts are privileged. Unknown emails
  still burn an Argon2 verification (`no_user_verify/0`) so timing does not
  enumerate accounts.
  """
  def authenticate_admin(email, credential) do
    case Repo.get_by(User, email: String.downcase(email || "")) do
      %User{} = user ->
        # Exactly ONE Argon2 verification on every existing-user path (wrong
        # password, right-password-but-not-admin, success) so timing cannot
        # distinguish the branches.
        if Argon2.verify_pass(credential || "", user.password_hash) && admin?(user) do
          {:ok, user}
        else
          {:error, :invalid_credentials}
        end

      nil ->
        Argon2.no_user_verify()
        {:error, :invalid_credentials}
    end
  end

  @doc "True when the user has a CONFIRMED TOTP enrollment."
  def totp_enabled?(%User{id: user_id}) do
    Repo.exists?(
      from t in TotpSecret, where: t.user_id == ^user_id and not is_nil(t.confirmed_at)
    )
  end

  @doc """
  Starts (or resumes) TOTP enrollment, returning the PLAINTEXT secret for
  provisioning-URI display. Idempotent while unconfirmed — revisiting the
  enrollment page shows the same secret. Refused once a confirmed factor
  exists (`{:error, :already_enrolled}`): rotating an active factor must be
  an explicit, separately-audited operation, not a silent overwrite.
  """
  def start_totp_enrollment(%User{id: user_id}) do
    case Repo.get_by(TotpSecret, user_id: user_id) do
      %TotpSecret{confirmed_at: %DateTime{}} ->
        {:error, :already_enrolled}

      %TotpSecret{} = pending ->
        SecretVault.decrypt(pending.secret_ciphertext)

      nil ->
        secret = TOTP.generate_secret()

        %TotpSecret{}
        |> TotpSecret.changeset(%{
          user_id: user_id,
          secret_ciphertext: SecretVault.encrypt(secret)
        })
        |> Repo.insert!()

        {:ok, secret}
    end
  end

  @doc """
  Confirms enrollment by proving possession: the code must match the pending
  secret. Sets `confirmed_at` and claims the matched timestep so the
  enrollment code cannot be replayed at login.
  """
  def confirm_totp_enrollment(%User{id: user_id}, code, opts \\ []) do
    now = Keyword.get(opts, :now, System.os_time(:second))

    with %TotpSecret{confirmed_at: nil} = pending <- Repo.get_by(TotpSecret, user_id: user_id),
         {:ok, secret} <- SecretVault.decrypt(pending.secret_ciphertext),
         {:ok, timestep} <- TOTP.match_timestep(secret, code, now) do
      pending
      |> Ecto.Changeset.change(
        confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second),
        last_used_timestep: timestep
      )
      |> Repo.update!()

      :ok
    else
      nil -> {:error, :not_enrolled}
      %TotpSecret{} -> {:error, :already_enrolled}
      _ -> {:error, :invalid_code}
    end
  end

  @doc """
  Second factor of the admin login (and of sensitive-action re-auth).

  Order matters: the lockout counter burns FIRST — every attempt, valid or
  not, counts — then the code is checked against the confirmed secret within
  the ±1-step skew window, then the matched timestep is claimed atomically
  (`UPDATE ... WHERE last_used_timestep < matched`), so a code can be
  accepted at most once even across concurrent requests (replay rejection,
  RFC 6238 §5.2).

  Returns `:ok`, `{:error, :invalid_code}`, or `{:error, :rate_limited}`.
  """
  def verify_totp(%User{id: user_id}, code, opts \\ []) do
    now = Keyword.get(opts, :now, System.os_time(:second))

    case RateLimiter.check(
           {:admin_totp, user_id},
           @totp_attempt_limit,
           @totp_window_ms,
           @totp_lockout_ms
         ) do
      {:error, :locked} ->
        {:error, :rate_limited}

      :ok ->
        with %TotpSecret{confirmed_at: %DateTime{}} = active <-
               Repo.get_by(TotpSecret, user_id: user_id),
             {:ok, secret} <- SecretVault.decrypt(active.secret_ciphertext),
             {:ok, timestep} <- TOTP.match_timestep(secret, code, now),
             {1, _} <- claim_timestep(active, timestep) do
          :ok
        else
          _ -> {:error, :invalid_code}
        end
    end
  end

  # Atomically advances the replay high-water mark. Returns {1, _} only when
  # this call moved it — a concurrent (or repeated) use of the same or an
  # older timestep matches zero rows and is rejected.
  defp claim_timestep(%TotpSecret{id: id}, timestep) do
    from(t in TotpSecret,
      where:
        t.id == ^id and (is_nil(t.last_used_timestep) or t.last_used_timestep < ^timestep)
    )
    |> Repo.update_all(set: [last_used_timestep: timestep])
  end

  @doc """
  Appends an admin audit event; raises on failure (an admin action must not
  proceed unauditable). `opts`: `:actor` (a `%User{}` or nil), `:metadata`
  (map), `:remote_ip` (string).
  """
  def audit!(action, opts \\ []) when is_binary(action) do
    actor = Keyword.get(opts, :actor)

    %AuditEvent{}
    |> AuditEvent.changeset(%{
      actor_id: actor && actor.id,
      actor_email: actor && actor.email,
      action: action,
      metadata: Keyword.get(opts, :metadata, %{}),
      remote_ip: Keyword.get(opts, :remote_ip)
    })
    |> Repo.insert!()
  end
end
