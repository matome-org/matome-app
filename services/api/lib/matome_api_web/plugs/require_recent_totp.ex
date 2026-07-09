defmodule MatomeApiWeb.Plugs.RequireRecentTotp do
  @moduledoc """
  Sensitive-action re-auth gate (W3 #1871, §9.1 "per-sensitive-action
  re-auth binding").

  Mount this plug (after `RequireAdminSession`) on any route performing a
  destructive/privileged admin action. It requires the session's TOTP
  verification to be FRESH (`MatomeApiWeb.AdminAuth.reauth_ttl_seconds/0`,
  default 5 min) — a hijacked but idle admin session cannot fire sensitive
  actions without the attacker also holding the second factor. Stale
  sessions are bounced to /admin/mfa, which re-verifies and returns.

  No admin data views exist yet (they arrive in later waves); this plug is
  shipped and tested now so those waves have the binding ready-made.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  alias MatomeApiWeb.AdminAuth

  def init(opts), do: opts

  def call(conn, _opts) do
    if AdminAuth.recent_totp?(get_session(conn)) do
      conn
    else
      conn
      |> redirect(to: "/admin/mfa?return_to=#{URI.encode_www_form(conn.request_path)}")
      |> halt()
    end
  end
end
