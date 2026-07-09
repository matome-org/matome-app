defmodule MatomeApiWeb.Plugs.AdminNetworkGuard do
  @moduledoc """
  Network gate for every /admin route (W3 #1871) — the OUTERMOST layer of
  the defense-in-depth stack, ahead of authentication.

  Delegates the decision to `MatomeApi.Admin.NetworkPolicy` (config-driven
  CIDR allowlist; X-Forwarded-For honored only through the pinned
  trusted-proxy chain; fail-closed on empty/ambiguous config). Denials are a
  plain 404 so the existence of the back-office is not advertised to
  scanners, and are logged — a request that reached a denied /admin from an
  unexpected network is signal.
  """

  import Plug.Conn

  require Logger

  alias MatomeApi.Admin.NetworkPolicy

  def init(opts), do: opts

  def call(conn, _opts) do
    xff = get_req_header(conn, "x-forwarded-for")

    if NetworkPolicy.allowed?(conn.remote_ip, xff) do
      conn
    else
      Logger.warning("admin network guard denied #{:inet.ntoa(conn.remote_ip)} #{conn.request_path}")

      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(404, "Not Found")
      |> halt()
    end
  end
end
