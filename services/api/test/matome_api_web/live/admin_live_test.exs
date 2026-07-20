defmodule MatomeApiWeb.AdminLiveTest do
  @moduledoc """
  /admin shell dead-render behind the email-OTP session gate.
  """
  use MatomeApiWeb.ConnCase

  defp admin_session(conn) do
    original = Application.get_env(:matome_api, :admin_panel)

    Application.put_env(
      :matome_api,
      :admin_panel,
      Keyword.merge(original || [], enabled: true, email_allowlist: ["shell@example.com"])
    )

    on_exit(fn -> Application.put_env(:matome_api, :admin_panel, original) end)

    now = System.os_time(:second)

    Plug.Test.init_test_session(conn, %{
      "admin_email" => "shell@example.com",
      "admin_authenticated_at" => now,
      "admin_otp_verified_at" => now
    })
  end

  test "GET /admin dead-renders the admin shell for an authenticated admin", %{conn: conn} do
    conn = conn |> admin_session() |> get("/admin")
    html = html_response(conn, 200)

    assert html =~ ~s(<meta name="csrf-token")
    assert html =~ "/assets/app.css"
    assert html =~ "/assets/app.js"
    assert html =~ "Admin"
    assert html =~ "/admin/users"
    assert html =~ "/admin/audit"
    assert html =~ "/admin/sessions"
    assert html =~ "matome · back-office"
    assert html =~ "Total users"
    assert html =~ "Active users"
    assert html =~ "Active devices"
    assert html =~ "Total storage"
    assert html =~ "Users"
    assert html =~ "Devices"
    assert html =~ "Access by form factor"
    assert html =~ "Access by device"
    assert html =~ "Access by OS"
    assert html =~ "Spaces"
    assert html =~ "Active"
    assert html =~ "Inactive"
  end

  test "GET /admin without a session is redirected to the login screen", %{conn: conn} do
    assert conn |> get("/admin") |> redirected_to() == "/admin/login"
  end
end
