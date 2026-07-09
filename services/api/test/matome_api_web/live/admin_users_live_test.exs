defmodule MatomeApiWeb.AdminUsersLiveTest do
  @moduledoc """
  W7 (#1875) — the §9.6 Users LiveView behind the W3 gate.

  Connected `live/2` needs the absent `lazy_html` dep, so coverage follows
  the W0/W6 pattern: dead-render through the full endpoint pipeline.
  """
  use MatomeApiWeb.ConnCase

  alias MatomeApi.Admin
  alias MatomeApi.Auth
  alias MatomeApi.Repo

  defp register!(email, meta \\ %{}) do
    {:ok, auth} =
      Auth.register_user(%{"email" => email, "password" => "correct horse battery"}, meta)

    auth
  end

  defp admin!(email) do
    register!(email).user
    |> Ecto.Changeset.change(role: "admin")
    |> Repo.update!()
  end

  defp admin_session(conn, admin) do
    now = System.os_time(:second)

    Plug.Test.init_test_session(conn, %{
      "admin_user_id" => admin.id,
      "admin_authenticated_at" => now,
      "admin_totp_verified_at" => now
    })
  end

  describe "dead render" do
    test "renders methods, MFA status, last login, and the §9.4 caveat", %{conn: conn} do
      admin = admin!("users-admin@example.com")

      %{user: holder} =
        register!("listed-user@example.com", %{
          login_method: "password",
          ip: "203.0.113.44"
        })

      {:ok, secret} = Admin.start_totp_enrollment(holder)
      now = System.os_time(:second)
      code = NimbleTOTP.verification_code(secret, time: now)
      :ok = Admin.confirm_totp_enrollment(holder, code, now: now)

      html =
        conn
        |> admin_session(admin)
        |> get("/admin/users")
        |> html_response(200)

      assert html =~ "listed-user@example.com"
      assert html =~ "password"
      assert html =~ "TOTP on"
      assert html =~ "Last login" or html =~ "UTC"
      assert html =~ "cannot grant crypto access" or html =~ "permission, not crypto"
      assert html =~ "§9.4" or html =~ "encrypted"
    end

    test "redirects to login without an admin session", %{conn: conn} do
      assert conn |> get("/admin/users") |> redirected_to() == "/admin/login"
    end
  end
end
