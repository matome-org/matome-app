defmodule MatomeApiWeb.Plugs.AdminNetworkGuard do
  @moduledoc """
  Outermost /admin gate: the panel kill switch (`ADMIN_PANEL_ENABLED`).

  When disabled, every `/admin*` request is a plain 404 so the surface is
  not advertised. IP allowlisting is soft (rate-limit tier only) and is
  enforced by `AdminAuthRateLimit`, not here — staff may reach the panel
  from corporate laptops without a fixed VPN IP.
  """

  import Plug.Conn

  require Logger

  alias MatomeApi.Admin.NetworkPolicy

  def init(opts), do: opts

  def call(conn, _opts) do
    if NetworkPolicy.panel_enabled?() do
      conn
    else
      Logger.warning("admin panel disabled — denied #{conn.request_path}")

      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(404, "Not Found")
      |> halt()
    end
  end
end
