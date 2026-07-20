defmodule MatomeApiWeb.AdminAuditLiveTest do
  @moduledoc """
  W7 (#1875) — the §9.6 Audit-log LiveView behind the W3 gate.

  Dead-render + direct `handle_event` coverage (lazy_html-free W0 pattern).
  """
  use MatomeApiWeb.ConnCase

  alias MatomeApi.Admin
  alias MatomeApi.Auth
  alias MatomeApi.Events.Event
  alias MatomeApi.Repo
  alias MatomeApiWeb.AdminLive.Audit

  defp register!(email) do
    {:ok, auth} =
      Auth.register_user(%{"email" => email, "password" => "correct horse battery"})

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

  defp socket(admin, extra \\ %{}) do
    _conn = admin_session(build_conn(), admin)

    assigns =
      Map.merge(
        %{
          __changed__: %{},
          flash: %{},
          live_action: :index,
          current_admin: %{email: admin.email},
          client_ip: "192.0.2.88",
          filters: %{actor_email: nil, action: nil, target: nil, since: nil, until: nil},
          admins: [admin.email],
          events: []
        },
        extra
      )

    %Phoenix.LiveView.Socket{assigns: assigns}
  end

  describe "dead render" do
    test "renders audit rows and filter controls", %{conn: conn} do
      admin = admin!("audit-admin@example.com")

      Admin.audit!("admin.login",
        actor: %{email: admin.email},
        metadata: %{"target" => "self"},
        remote_ip: "203.0.113.9"
      )

      html =
        conn
        |> admin_session(admin)
        |> get("/admin/audit")
        |> html_response(200)

      assert html =~ "Audit log"
      assert html =~ "admin.login"
      assert html =~ "audit-admin@example.com"
      assert html =~ "203.0.113.9"
      assert html =~ ~s(name="actor_email")
      assert html =~ ~s(name="action")
      assert html =~ ~s(name="target")
      assert html =~ ~s(name="since")
      assert html =~ "append-only" or html =~ "cannot be edited"
    end

    test "redirects to login without an admin session", %{conn: conn} do
      assert conn |> get("/admin/audit") |> redirected_to() == "/admin/login"
    end
  end

  describe "handle_event filter" do
    test "narrows events by action and target" do
      admin = admin!("filter-admin@example.com")
      victim = register!("filter-victim@example.com").user

      Admin.audit!("admin.login",
        actor: %{email: admin.email},
        metadata: %{"target" => "self"}
      )

      Admin.audit!("admin.session_revoked",
        actor: %{email: admin.email},
        metadata: %{"user_id" => victim.id, "jti" => "tok-xyz"}
      )

      {:noreply, socket} =
        Audit.handle_event(
          "filter",
          %{
            "action" => "admin.session_revoked",
            "target" => to_string(victim.id),
            "actor_email" => ""
          },
          socket(admin)
        )

      assert length(socket.assigns.events) == 1
      assert hd(socket.assigns.events).event_key == "security.admin.session_revoked.v2"
      assert socket.assigns.filters.action == "admin.session_revoked"
      assert socket.assigns.filters.target == to_string(victim.id)
    end

    test "clear resets filters and reloads the full trail" do
      admin = admin!("clear-admin@example.com")
      Admin.audit!("admin.login", actor: %{email: admin.email})
      Admin.audit!("admin.logout", actor: %{email: admin.email})

      seeded =
        socket(admin, %{
          filters: %{
            actor_email: admin.email,
            action: "admin.login",
            target: nil,
            since: nil,
            until: nil
          },
          events:
            Repo.all(Event)
            |> Enum.filter(&(&1.event_key == "security.admin.login.v1"))
        })

      {:noreply, socket} = Audit.handle_event("clear", %{}, seeded)

      assert socket.assigns.filters.action == nil
      assert socket.assigns.filters.actor_email == nil
      assert length(socket.assigns.events) >= 2
    end
  end
end
