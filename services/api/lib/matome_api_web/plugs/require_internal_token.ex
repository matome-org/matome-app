defmodule MatomeApiWeb.Plugs.RequireInternalToken do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    expected = MatomeApi.AIEngine.token()

    if token_present?(expected) and
         get_req_header(conn, "authorization") == ["Bearer #{expected}"] do
      conn
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "unauthorized"})
      |> halt()
    end
  end

  defp token_present?(token), do: is_binary(token) and token != ""
end
