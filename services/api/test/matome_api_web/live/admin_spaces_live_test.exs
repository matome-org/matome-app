defmodule MatomeApiWeb.AdminSpacesLiveTest do
  @moduledoc """
  W8 (#1876) — Spaces LiveView behind the W3 admin gate (dead-render).
  """
  use MatomeApiWeb.ConnCase

  import Ecto.Query

  alias MatomeApi.Auth
  alias MatomeApi.Content
  alias MatomeApi.Content.Workspace
  alias MatomeApi.Events.Event
  alias MatomeApi.Repo
  alias MatomeApiWeb.AdminLive.Spaces

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

  defp socket(admin, selected, extra \\ %{}) do
    assigns =
      Map.merge(
        %{
          __changed__: %{},
          flash: %{},
          live_action: :index,
          current_admin: %{email: admin.email},
          otp_verified_at: System.os_time(:second),
          client_ip: "198.51.100.91",
          selected: Repo.preload(selected, [:owner, space_members: :user]),
          selected_id: selected.id,
          spaces: [],
          quota_input: "",
          expires_input: "",
          member_email: "",
          member_role: "member",
          flash_note: nil
        },
        extra
      )

    %Phoenix.LiveView.Socket{assigns: assigns}
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

  describe "privileged events" do
    test "save attributes the allowlisted actor and client IP" do
      admin = admin!("spaces-actor@example.com")
      %{user: owner} = register!("spaces-target-owner@example.com")
      {:ok, workspace} = Content.create_workspace(owner, %{name: "Attributed"})
      ensure = admin_session(build_conn(), admin)
      assert ensure

      {:noreply, _socket} =
        Spaces.handle_event(
          "save_quota",
          %{"quota" => "2048", "expires" => ""},
          socket(admin, workspace)
        )

      event =
        Repo.one!(
          from e in Event,
            where: like(e.event_key, "security.admin.space_updated.%")
        )

      assert event.actor_email == admin.email
      assert event.remote_ip == "198.51.100.91"
      assert event.subject_id == to_string(workspace.id)
      assert event.details["before"]
      assert event.details["after"]
    end

    test "stale OTP redirects without changing the space" do
      admin = admin!("spaces-stale@example.com")
      %{user: owner} = register!("spaces-stale-owner@example.com")
      {:ok, workspace} = Content.create_workspace(owner, %{name: "Unchanged"})
      _conn = admin_session(build_conn(), admin)

      {:noreply, result} =
        Spaces.handle_event(
          "save_quota",
          %{"quota" => "2048", "expires" => ""},
          socket(admin, workspace, %{otp_verified_at: System.os_time(:second) - 3600})
        )

      assert {:redirect, %{to: to}} = result.redirected
      assert to =~ "/admin/otp"
      assert is_nil(Repo.get!(Workspace, workspace.id).quota_bytes)
    end
  end
end
