defmodule MatomeApiWeb.Plugs.RequireResetToken do
  @moduledoc """
  Authenticates a request with a short-lived password-reset token (minted by
  `MatomeApi.Auth.request_password_reset/1`) instead of a normal session
  access token.

  Task #1854, plan #131 W3 — the pre-auth salt bootstrap (tracked
  carry-forward CF-1, see .docs/internal/at-rest-key-flow.md §5): during a
  "forgot password" reset the user has no session and so cannot reach the
  normal `:auth`-gated `/keybundle` routes. Proof of email ownership (the
  reset token already minted by the existing forgot-password flow) stands
  in for the normal Bearer access token here — scoped ONLY to the
  `/keybundle/recovery` routes (see router.ex), never to any other
  authenticated route.

  Mirrors `MatomeApiWeb.Plugs.RequireAuth` exactly, except it calls
  `Auth.verify_reset_token/1` (which requires the Guardian `"typ" => "reset"`
  claim) instead of `Auth.verify_access_token/1` (`"typ" => "access"`) — a
  normal session access token is explicitly rejected here, and a reset token
  is explicitly rejected by `RequireAuth`. The two auth channels never mix.
  """
  import Plug.Conn
  import Phoenix.Controller

  alias MatomeApi.Auth

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, user, _claims} <- Auth.verify_reset_token(token) do
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
