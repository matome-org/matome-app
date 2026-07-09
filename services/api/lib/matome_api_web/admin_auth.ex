defmodule MatomeApiWeb.AdminAuth do
  @moduledoc """
  Session management for the /admin back-office (W3 #1871).

  The admin session is deliberately SEPARATE from the Guardian JWT stack the
  JSON API uses: it is a short-lived, server-checked cookie session that only
  exists after BOTH factors (password + TOTP) succeeded.

  Lifecycle:

  1. `put_pending_admin/2` — first factor passed; the session holds only a
     pending marker. Nothing behind the gate is reachable yet.
  2. `complete_admin_login/2` — TOTP verified; the session is renewed
     (fixation defense) and stamped with `authenticated_at` and
     `totp_verified_at`.
  3. `current_admin/1`-style checks enforce the ABSOLUTE TTL
     (`@session_ttl_seconds`, default #{30} min): past it the admin
     re-authenticates fully, no sliding renewal.
  4. Sensitive actions additionally require `recent_totp?/1`
     (`@reauth_ttl_seconds`, default #{5} min) — see
     `MatomeApiWeb.Plugs.RequireRecentTotp`; re-verification bumps only the
     TOTP stamp via `refresh_totp_verification/1`.

  `on_mount/4` guards the LiveView surface: dead renders were already gated
  by the router pipelines; CONNECTED mounts re-check the session AND re-run
  the network policy against the websocket peer (`peer_data` + `x_headers`
  from `connect_info`), because the websocket upgrade does not traverse the
  /admin router pipelines.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  alias MatomeApi.Admin
  alias MatomeApi.Admin.NetworkPolicy
  alias MatomeApi.Auth

  @pending_key "admin_pending_user_id"
  @user_key "admin_user_id"
  @auth_at_key "admin_authenticated_at"
  @totp_at_key "admin_totp_verified_at"

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

  @doc "First factor passed — park the user as pending until TOTP succeeds."
  def put_pending_admin(conn, user) do
    conn
    |> renew_session()
    |> put_session(@pending_key, user.id)
  end

  @doc "Resolves the pending (password-verified, TOTP-outstanding) admin, or nil."
  def pending_admin(conn) do
    with id when is_integer(id) <- get_session(conn, @pending_key),
         %{} = user <- Auth.get_user(id),
         true <- Admin.admin?(user) do
      user
    else
      _ -> nil
    end
  end

  @doc "Both factors passed — establish the real admin session."
  def complete_admin_login(conn, user) do
    now = System.os_time(:second)

    conn
    |> renew_session()
    |> put_session(@user_key, user.id)
    |> put_session(@auth_at_key, now)
    |> put_session(@totp_at_key, now)
  end

  @doc "Bumps only the TOTP stamp after a sensitive-action re-verification."
  def refresh_totp_verification(conn) do
    put_session(conn, @totp_at_key, System.os_time(:second))
  end

  @doc "Drops the whole admin session."
  def log_out_admin(conn), do: renew_session(conn)

  @doc """
  Resolves the fully-authenticated admin from a session map (works for both
  `get_session(conn)` and the LiveView `on_mount` session). Enforces the
  role allowlist AND the absolute TTL on every request — a role revoked or a
  session past TTL is rejected mid-flight, not at next login.
  """
  def admin_from_session(session, now \\ System.os_time(:second)) do
    with id when is_integer(id) <- session[@user_key],
         auth_at when is_integer(auth_at) <- session[@auth_at_key],
         true <- now < auth_at + session_ttl_seconds(),
         %{} = user <- Auth.get_user(id),
         true <- Admin.admin?(user) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  @doc "True when the session's TOTP verification is fresh enough for sensitive actions."
  def recent_totp?(session, now \\ System.os_time(:second)) do
    case session[@totp_at_key] do
      totp_at when is_integer(totp_at) -> now < totp_at + reauth_ttl_seconds()
      _ -> false
    end
  end

  @doc """
  Plug: require a fully-authenticated, in-TTL admin; assigns
  `:current_admin` or redirects to the login screen.
  """
  def require_admin(conn, _opts) do
    case admin_from_session(get_session(conn)) do
      {:ok, user} ->
        assign(conn, :current_admin, user)

      :error ->
        conn
        |> redirect(to: "/admin/login")
        |> halt()
    end
  end

  @doc """
  LiveView `on_mount` gate. Connected mounts re-run the network policy
  against the websocket peer — the upgrade request does not pass through
  the /admin router pipelines, so without this a valid session could ride
  a socket opened from outside the allowlist.
  """
  def on_mount(:require_admin, _params, session, socket) do
    with {:ok, user} <- admin_from_session(session),
         :ok <- check_socket_network(socket) do
      {:cont, Phoenix.Component.assign(socket, :current_admin, user)}
    else
      _ -> {:halt, Phoenix.LiveView.redirect(socket, to: "/admin/login")}
    end
  end

  defp check_socket_network(socket) do
    if Phoenix.LiveView.connected?(socket) do
      peer = Phoenix.LiveView.get_connect_info(socket, :peer_data)
      x_headers = Phoenix.LiveView.get_connect_info(socket, :x_headers) || []
      xff = for {"x-forwarded-for", value} <- x_headers, do: value

      if peer != nil and NetworkPolicy.allowed?(peer.address, xff), do: :ok, else: :error
    else
      # Dead render: the HTTP request already traversed AdminNetworkGuard.
      :ok
    end
  end

  # Fresh session id + emptied storage: keeps an attacker-provided
  # pre-login cookie from becoming an authenticated session (fixation).
  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end
end
