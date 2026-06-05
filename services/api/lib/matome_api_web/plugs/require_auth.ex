defmodule MatomeApiWeb.Plugs.RequireAuth do
  import Plug.Conn
  import Phoenix.Controller

  alias MatomeApi.Auth

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, user, _claims} <- Auth.verify_access_token(token) do
      assign(conn, :current_user, user)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "unauthorized"})
        |> halt()
    end
  end
end
