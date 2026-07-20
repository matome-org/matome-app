defmodule MatomeApiWeb.Plugs.RequireAdminSession do
  @moduledoc """
  Pipeline plug wrapper for `MatomeApiWeb.AdminAuth.require_admin/2` (W3
  #1871): rejects any /admin request without a fully-authenticated (password
  + TOTP), in-TTL admin session.
  """

  def init(opts), do: opts

  def call(conn, opts), do: MatomeApiWeb.AdminAuth.require_admin(conn, opts)
end
