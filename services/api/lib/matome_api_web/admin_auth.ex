defmodule MatomeApiWeb.AdminAuth do
  @moduledoc """
  Cookie session for the /admin back-office (email-OTP gate).

  Separate from the Guardian JWT stack. Lifecycle:

  1. `put_pending_email/2` — allowlisted email requested an OTP; nothing
     behind the gate is reachable yet.
  2. `complete_admin_login/2` — OTP verified; session renewed (fixation)
     and stamped with `admin_email`, `authenticated_at`, `otp_verified_at`.
  3. Absolute TTL (default 30 min, no sliding renewal).
  4. Sensitive actions require fresh OTP (`recent_otp?/1`); re-verify bumps
     only the OTP stamp via `refresh_otp_verification/1`.

  Identity is the allowlisted email string — no `users` row required.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  alias MatomeApi.Admin.NetworkPolicy

  @pending_key "admin_pending_email"
  @email_key "admin_email"
  @auth_at_key "admin_authenticated_at"
  @otp_at_key "admin_otp_verified_at"

  @session_ttl_seconds 30 * 60
  @reauth_ttl_seconds 5 * 60

  @doc "Absolute admin session TTL in seconds (config-overridable)."
  def session_ttl_seconds do
    Application.get_env(:matome_api, :admin_session, [])[:ttl_seconds] || @session_ttl_seconds
  end

  @doc "Freshness window for sensitive-action re-auth in seconds."
  def reauth_ttl_seconds do
    Application.get_env(:matome_api, :admin_session, [])[:reauth_ttl_seconds] ||
      @reauth_ttl_seconds
  end

  @doc """
  OTP requested — park the email as pending until the code verifies.

  When already authenticated (re-auth), keeps the admin session and only
  sets the pending marker. Fresh logins renew/clear to defeat fixation.
  """
  def put_pending_email(conn, email) when is_binary(email) do
    email = normalize(email)

    case admin_from_session(get_session(conn)) do
      {:ok, _} ->
        put_session(conn, @pending_key, email)

      :error ->
        conn
        |> renew_session()
        |> put_session(@pending_key, email)
    end
  end

  @doc "Pending (OTP-outstanding) email, or nil."
  def pending_email(conn) do
    case get_session(conn, @pending_key) do
      email when is_binary(email) and email != "" -> email
      _ -> nil
    end
  end

  @doc "OTP verified — establish the real admin session."
  def complete_admin_login(conn, email) when is_binary(email) do
    now = System.os_time(:second)

    conn
    |> renew_session()
    |> put_session(@email_key, normalize(email))
    |> put_session(@auth_at_key, now)
    |> put_session(@otp_at_key, now)
  end

  @doc "Bumps only the OTP stamp after a sensitive-action re-verification."
  def refresh_otp_verification(conn) do
    conn
    |> put_session(@otp_at_key, System.os_time(:second))
    |> delete_session(@pending_key)
  end

  @doc "Clears a pending OTP email without touching the authenticated session."
  def clear_pending_email(conn), do: delete_session(conn, @pending_key)

  @doc "Drops the whole admin session."
  def log_out_admin(conn), do: renew_session(conn)

  @doc """
  Resolves the fully-authenticated admin from a session map. Enforces the
  email allowlist AND the absolute TTL on every request.
  """
  def admin_from_session(session, now \\ System.os_time(:second)) do
    with email when is_binary(email) <- session[@email_key],
         auth_at when is_integer(auth_at) <- session[@auth_at_key],
         true <- now < auth_at + session_ttl_seconds(),
         true <- NetworkPolicy.email_allowed?(email) do
      {:ok, %{email: normalize(email)}}
    else
      _ -> :error
    end
  end

  @doc "True when the session's OTP verification is fresh enough for sensitive actions."
  def recent_otp?(session, now \\ System.os_time(:second)) do
    case session[@otp_at_key] do
      otp_at when is_integer(otp_at) -> now < otp_at + reauth_ttl_seconds()
      _ -> false
    end
  end

  @doc """
  Plug: require a fully-authenticated, in-TTL admin; assigns
  `:current_admin` or redirects to the login screen.
  """
  def require_admin(conn, _opts) do
    case admin_from_session(get_session(conn)) do
      {:ok, admin} ->
        assign(conn, :current_admin, admin)

      :error ->
        conn
        |> redirect(to: "/admin/login")
        |> halt()
    end
  end

  @doc """
  LiveView `on_mount` gate. Re-checks panel enabled + session; network is
  soft (no hard deny on IP).
  """
  def on_mount(:require_admin, _params, session, socket) do
    with true <- NetworkPolicy.panel_enabled?(),
         {:ok, admin} <- admin_from_session(session) do
      {:cont, Phoenix.Component.assign(socket, :current_admin, admin)}
    else
      _ -> {:halt, Phoenix.LiveView.redirect(socket, to: "/admin/login")}
    end
  end

  defp normalize(email), do: email |> String.trim() |> String.downcase()

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end
end
