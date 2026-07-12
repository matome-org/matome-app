defmodule MatomeApiWeb.AdminUsersLiveTest do
  @moduledoc """
  W7 (#1875) — the §9.6 Users LiveView behind the W3 gate.

  Connected `live/2` needs the absent `lazy_html` dep, so coverage follows
  the W0/W6 pattern: dead-render through the full endpoint pipeline.
  """
  use MatomeApiWeb.ConnCase

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
    original = Application.get_env(:matome_api, :admin_panel)

    Application.put_env(
      :matome_api,
      :admin_panel,
      Keyword.merge(original || [], enabled: true, email_allowlist: [admin.email])
    )

    on_exit(fn -> Application.put_env(:matome_api, :admin_panel, original) end)

    now = System.os_time(:second)

    Plug.Test.init_test_session(conn, %{
      "admin_email" => admin.email,
      "admin_authenticated_at" => now,
      "admin_otp_verified_at" => now
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

      # MFA badge still reads confirmed totp_secrets rows (app-user MFA, not admin gate).
      %MatomeApi.Admin.TotpSecret{}
      |> MatomeApi.Admin.TotpSecret.changeset(%{
        user_id: holder.id,
        secret_ciphertext: <<1, 2, 3, 4>>,
        confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
      |> Repo.insert!()

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
