defmodule MatomeApiWeb.AdminLiveTest do
  @moduledoc """
  Wave 0 (#1868) acceptance, updated for the W3 (#1871) gate: the /admin
  shell renders under the LiveView pipeline — but only BEHIND the
  defense-in-depth gate (network guard + two-factor admin session). The
  rejection paths (out-of-network, non-admin, no/partial session) live in
  `MatomeApiWeb.AdminAccessTest`.
  """
  use MatomeApiWeb.ConnCase

  # NOTE: the connected `live/2` socket assertion needs the `lazy_html` test
  # dep (a C-NIF unavailable in the W0 offline wave). The dead-render GET
  # below already exercises the LiveView mount + render + layouts + asset
  # wiring through the endpoint pipeline; add the `live/2` mount test once
  # lazy_html is added. (W0 #1868)

  defp admin_session(conn) do
    email = "shell-admin-#{System.unique_integer([:positive])}@example.com"

    {:ok, %{user: user}} =
      MatomeApi.Auth.register_user(%{"email" => email, "password" => "correct horse battery"})

    user = user |> Ecto.Changeset.change(role: "admin") |> MatomeApi.Repo.update!()
    now = System.os_time(:second)

    Plug.Test.init_test_session(conn, %{
      "admin_user_id" => user.id,
      "admin_authenticated_at" => now,
      "admin_totp_verified_at" => now
    })
  end

  test "GET /admin dead-renders the admin shell for an authenticated admin", %{conn: conn} do
    conn = conn |> admin_session() |> get("/admin")
    html = html_response(conn, 200)

    # Root layout wired the compiled asset bundle + csrf token.
    assert html =~ ~s(<meta name="csrf-token")
    assert html =~ "/assets/app.css"
    assert html =~ "/assets/app.js"
    # The AdminLive.Index empty-shell content rendered.
    assert html =~ "Admin"
    assert html =~ "/admin/users"
    assert html =~ "/admin/audit"
    assert html =~ "matome · back-office"
  end

  test "GET /admin without a session is redirected to the login screen", %{conn: conn} do
    assert conn |> get("/admin") |> redirected_to() == "/admin/login"
  end
end
