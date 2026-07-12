defmodule MatomeApiWeb.AdminSpacesLiveTest do
  @moduledoc """
  W8 (#1876) — Spaces LiveView behind the W3 admin gate (dead-render).
  """
  use MatomeApiWeb.ConnCase

  alias MatomeApi.Auth
  alias MatomeApi.Content
  alias MatomeApi.Content.Workspace
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
    test "lists spaces with two-axis + quota and the §9.4 caveat", %{conn: conn} do
      admin = admin!("spaces-admin@example.com")
      %{user: owner} = register!("space-owner@example.com")

      {:ok, workspace} = Content.create_workspace(owner, %{name: "Research Lab"})

      workspace
      |> Workspace.admin_changeset(%{quota_bytes: 5_000, space_type: "personal"})
      |> Repo.update!()

      html =
        conn
        |> admin_session(admin)
        |> get("/admin/spaces")
        |> html_response(200)

      assert html =~ "Research Lab"
      assert html =~ "space-owner@example.com"
      assert html =~ "cloud"
      assert html =~ "active"
      assert html =~ "cannot grant crypto" or html =~ "permission, not crypto"
      assert html =~ "§9.4" or html =~ "space-KEK"
    end

    test "redirects to login without an admin session", %{conn: conn} do
      assert conn |> get("/admin/spaces") |> redirected_to() == "/admin/login"
    end
  end
end
