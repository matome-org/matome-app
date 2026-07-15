defmodule MatomeApiWeb.Plugs.RequireAuth do
  import Plug.Conn
  import Phoenix.Controller

  alias MatomeApi.Auth

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, user, claims} <- Auth.verify_access_token(token) do
      conn
      |> assign(:current_user, user)
      |> assign(:current_device_id, Auth.session_device_id(user, claims["sid"]))
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "unauthorized"})
        |> halt()
    end
  end
end
