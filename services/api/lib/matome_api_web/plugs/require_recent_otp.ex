defmodule MatomeApiWeb.Plugs.RequireRecentOtp do
  @moduledoc """
  Requires a fresh admin OTP verification for sensitive actions.
  Stale sessions bounce to `/admin/otp` with a safe `return_to`.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  alias MatomeApiWeb.AdminAuth

  def init(opts), do: opts

  def call(conn, _opts) do
    if AdminAuth.recent_otp?(get_session(conn)) do
      conn
    else
      return_to = conn.request_path

      conn
      |> redirect(to: "/admin/otp?return_to=#{URI.encode_www_form(return_to)}")
      |> halt()
    end
  end
end
