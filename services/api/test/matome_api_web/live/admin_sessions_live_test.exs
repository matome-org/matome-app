defmodule MatomeApiWeb.AdminSessionsLiveTest do
  @moduledoc """
  W6 (#1874) — the §9.2 Sessions LiveView behind the W3 gate.

  Connected `live/2` tests still need the `lazy_html` dep (absent since W0),
  so coverage follows the established pattern: dead-render through the full
  endpoint pipeline + direct handler tests on the LiveView callbacks
  (`handle_event`/`handle_info`) with a hand-built socket.
  """
  use MatomeApiWeb.ConnCase

  import Ecto.Query

  alias MatomeApi.Admin.AuditEvent
  alias MatomeApi.Auth
  alias MatomeApi.Auth.RefreshToken
  alias MatomeApi.Repo
  alias MatomeApiWeb.AdminLive.Sessions

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

  defp ensure_allowlist!(email) do
    original = Application.get_env(:matome_api, :admin_panel)

    Application.put_env(
      :matome_api,
      :admin_panel,
      Keyword.merge(original || [], enabled: true, email_allowlist: [email])
    )

    on_exit(fn -> Application.put_env(:matome_api, :admin_panel, original) end)
  end

  defp admin_session(conn, admin) do
    ensure_allowlist!(admin.email)
    now = System.os_time(:second)

    Plug.Test.init_test_session(conn, %{
      "admin_email" => admin.email,
      "admin_authenticated_at" => now,
      "admin_otp_verified_at" => now
    })
  end

  defp socket(admin, extra \\ %{}) do
    assigns =
      Map.merge(
        %{
          __changed__: %{},
          flash: %{},
          live_action: :index,
          current_admin: %{email: admin.email},
          otp_verified_at: System.os_time(:second),
          peer_ip: "192.0.2.99",
          sessions: [],
          now: DateTime.utc_now()
        },
        extra
      )

    %Phoenix.LiveView.Socket{assigns: assigns}
  end

  describe "dead render" do
    test "renders the user -> device -> token hierarchy", %{conn: conn} do
      admin = admin!("sessions-admin@example.com")

      register!("session-holder@example.com", %{
        ip: "203.0.113.7",
        user_agent: "MatomeApp/1.0 (linux)",
        login_method: "password",
        device: %{
          "id" => Ecto.UUID.generate(),
          "platform" => "linux",
          "display_name" => "Dev laptop"
        }
      })

      html =
        conn
        |> admin_session(admin)
        |> get("/admin/sessions")
        |> html_response(200)

      assert html =~ "session-holder@example.com"
      assert html =~ "Dev laptop"
      assert html =~ "203.0.113.7"
      assert html =~ "password"
      assert html =~ "Revoke"
      # Status is the honest degraded signal, never a Presence claim.
      assert html =~ "Last seen" or html =~ "Active"
    end

    test "redirects to login without an admin session", %{conn: conn} do
      assert conn |> get("/admin/sessions") |> redirected_to() == "/admin/login"
    end
  end

  describe "handle_event revoke" do
    test "with fresh OTP revokes the family and audits" do
      admin = admin!("revoking-admin@example.com")
      %{refresh_token: refresh_token} = register!("victim@example.com")
      %RefreshToken{jti: jti} = Repo.get_by!(RefreshToken, token: refresh_token)

      {:noreply, socket} = Sessions.handle_event("revoke", %{"jti" => jti}, socket(admin))

      assert %RefreshToken{revoked_at: %DateTime{}} = Repo.get_by!(RefreshToken, jti: jti)

      audit = Repo.one!(from e in AuditEvent, where: e.action == "admin.session_revoked")
      assert audit.actor_id == nil
      assert audit.actor_email == admin.email
      assert audit.remote_ip == "192.0.2.99"
      assert socket.assigns.flash["info"] =~ "revoked"
    end

    test "with stale OTP redirects to re-auth and revokes nothing" do
      admin = admin!("stale-admin@example.com")
      %{refresh_token: refresh_token} = register!("safe@example.com")
      %RefreshToken{jti: jti} = Repo.get_by!(RefreshToken, token: refresh_token)

      stale = System.os_time(:second) - 3600

      {:noreply, socket} =
        Sessions.handle_event(
          "revoke",
          %{"jti" => jti},
          socket(admin, %{otp_verified_at: stale})
        )

      assert {:redirect, %{to: to}} = socket.redirected
      assert to =~ "/admin/otp"
      assert to =~ "return_to="

      assert %RefreshToken{revoked_at: nil} = Repo.get_by!(RefreshToken, jti: jti)
      refute Repo.exists?(from e in AuditEvent, where: e.action == "admin.session_revoked")
    end

    test "unknown jti flashes an error" do
      admin = admin!("confused-admin@example.com")

      {:noreply, socket} =
        Sessions.handle_event("revoke", %{"jti" => Ecto.UUID.generate()}, socket(admin))

      assert socket.assigns.flash["error"] =~ "not found"
    end
  end

  describe "handle_info allowlist invalidation" do
    test "reloads the tree so revocations elsewhere update the view" do
      admin = admin!("watching-admin@example.com")
      %{refresh_token: refresh_token} = register!("leaver@example.com")
      %RefreshToken{jti: jti} = Repo.get_by!(RefreshToken, token: refresh_token)

      # Seed the socket with the pre-revocation tree.
      socket = socket(admin, %{sessions: MatomeApi.Admin.session_tree()})
      assert Enum.any?(socket.assigns.sessions, &(&1.user.email == "leaver@example.com"))

      :ok = Auth.logout(refresh_token)

      {:noreply, socket} =
        Sessions.handle_info({:token_allowlist_invalidate, jti}, socket)

      refute Enum.any?(socket.assigns.sessions, &(&1.user.email == "leaver@example.com"))
    end
  end
end
