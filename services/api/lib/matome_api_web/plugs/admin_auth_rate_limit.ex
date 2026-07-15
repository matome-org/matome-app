defmodule MatomeApiWeb.Plugs.AdminAuthRateLimit do
  @moduledoc """
  Per-IP rate limit for admin login / OTP posts.

  Soft `ADMIN_IP_ALLOWLIST` tiers the limits: IPs inside (or empty list)
  get the normal bucket; everyone else still reaches the panel but under
  stricter caps. Returns plain 429 — these are browser forms.
  """

  import Plug.Conn

  alias MatomeApi.Admin.NetworkPolicy
  alias MatomeApi.RateLimiter

  @normal_limit 30
  @strict_limit 5
  @window_ms 60_000
  @lockout_ms 60_000

  def init(opts), do: opts

  def call(conn, opts) do
    scope = Keyword.get(opts, :scope, :admin_login)
    xff = get_req_header(conn, "x-forwarded-for")
    trusted = NetworkPolicy.soft_trusted_ip?(conn.remote_ip, xff)
    limit = if trusted, do: @normal_limit, else: @strict_limit
    key = {scope, :ip, ip_string(conn, xff), if(trusted, do: :trusted, else: :strict)}

    case RateLimiter.check(key, limit, @window_ms, @lockout_ms) do
      :ok ->
        conn

      {:error, :locked} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(429, "Too Many Requests")
        |> halt()
    end
  end

  defp ip_string(conn, xff) do
    case NetworkPolicy.client_ip(conn.remote_ip, xff) do
      {:ok, ip} -> ip |> :inet.ntoa() |> to_string()
      :error -> "invalid-proxy-chain"
    end
  end
end
