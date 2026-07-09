defmodule MatomeApiWeb.AdminAuditLiveTest do
  @moduledoc """
  W7 (#1875) — the §9.6 Audit-log LiveView behind the W3 gate.

  Dead-render + direct `handle_event` coverage (lazy_html-free W0 pattern).
  """
  use MatomeApiWeb.ConnCase

  alias MatomeApi.Admin
  alias MatomeApi.Admin.AuditEvent
  alias MatomeApi.Auth
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
    now = System.os_time(:second)

    Plug.Test.init_test_session(conn, %{
      "admin_user_id" => admin.id,
      "admin_authenticated_at" => now,
      "admin_totp_verified_at" => now
    })
  end

  defp socket(admin, extra \\ %{}) do
    assigns =
      Map.merge(
        %{
          __changed__: %{},
          flash: %{},
          live_action: :index,
          current_admin: admin,
          filters: %{actor_id: nil, action: nil, target: nil, since: nil, until: nil},
          admins: [admin],
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
        actor: admin,
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
      assert html =~ ~s(name="actor_id")
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

      Admin.audit!("admin.login", actor: admin, metadata: %{"target" => "self"})
      Admin.audit!("admin.session_revoked",
        actor: admin,
        metadata: %{"user_id" => 99, "jti" => "tok-xyz"}
      )

      {:noreply, socket} =
        Audit.handle_event(
          "filter",
          %{"action" => "admin.session_revoked", "target" => "99", "actor_id" => ""},
          socket(admin)
        )

      assert length(socket.assigns.events) == 1
      assert hd(socket.assigns.events).action == "admin.session_revoked"
      assert socket.assigns.filters.action == "admin.session_revoked"
      assert socket.assigns.filters.target == "99"
    end

    test "clear resets filters and reloads the full trail" do
      admin = admin!("clear-admin@example.com")
      Admin.audit!("admin.login", actor: admin)
      Admin.audit!("admin.logout", actor: admin)

      seeded =
        socket(admin, %{
          filters: %{
            actor_id: admin.id,
            action: "admin.login",
            target: nil,
            since: nil,
            until: nil
          },
          events: Repo.all(AuditEvent) |> Enum.filter(&(&1.action == "admin.login"))
        })

      {:noreply, socket} = Audit.handle_event("clear", %{}, seeded)

      assert socket.assigns.filters.action == nil
      assert length(socket.assigns.events) >= 2
    end
  end
end
