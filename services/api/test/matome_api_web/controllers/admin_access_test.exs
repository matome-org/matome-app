defmodule MatomeApiWeb.AdminAccessTest do
  @moduledoc """
  W3 #1871 acceptance — the /admin defense-in-depth gate end to end:

  - rejected outside the network guard (404, existence not advertised);
  - rejected for non-admin role (indistinguishable from bad password);
  - rejected without a valid TOTP (pending session grants nothing);
  - short absolute session TTL; sensitive-action re-auth plug;
  - audit rows written for admin login and admin actions from day one.
  """
  use MatomeApiWeb.ConnCase, async: false

  import Ecto.Query

  alias MatomeApi.Admin
  alias MatomeApi.Admin.AuditEvent
  alias MatomeApi.Auth
  alias MatomeApi.Repo

  @password "correct horse battery staple"

  defp create_admin!(opts \\ []) do
    email = "admin-#{System.unique_integer([:positive])}@example.com"
    {:ok, %{user: user}} = Auth.register_user(%{"email" => email, "password" => @password})

    user =
      user |> Ecto.Changeset.change(role: Keyword.get(opts, :role, "admin")) |> Repo.update!()

    secret =
      if Keyword.get(opts, :enroll, true) do
        {:ok, secret} = Admin.start_totp_enrollment(user)
        # Confirm with a PAST timestep so the enrollment's replay high-water
        # mark does not swallow the login code the test sends "now".
        past = System.os_time(:second) - 90

        :ok =
          Admin.confirm_totp_enrollment(user, NimbleTOTP.verification_code(secret, time: past),
            now: past
          )

        secret
      end

    {user, secret}
  end

  defp current_code(secret), do: NimbleTOTP.verification_code(secret)

  defp audit_actions(user_id) do
    Repo.all(
      from e in AuditEvent, where: e.actor_id == ^user_id, order_by: e.id, select: e.action
    )
  end

  describe "network guard" do
    test "rejects /admin from an IP outside the allowlist with 404", %{conn: conn} do
      conn = %{conn | remote_ip: {203, 0, 113, 5}}

      assert conn |> get("/admin") |> response(404)
    end

    test "rejects the login screen too — the surface does not exist outside", %{conn: conn} do
      conn = %{conn | remote_ip: {203, 0, 113, 5}}

      assert conn |> get("/admin/login") |> response(404)
    end

    test "a spoofed X-Forwarded-For from an untrusted peer is ignored", %{conn: conn} do
      conn =
        %{conn | remote_ip: {203, 0, 113, 5}}
        |> put_req_header("x-forwarded-for", "127.0.0.1")

      assert conn |> get("/admin") |> response(404)
    end

    test "fails closed when the allowlist is empty (undecided-topology prod default)", %{
      conn: conn
    } do
      original = Application.get_env(:matome_api, :admin_network)
      on_exit(fn -> Application.put_env(:matome_api, :admin_network, original) end)
      Application.put_env(:matome_api, :admin_network, allowlist: [], trusted_proxies: [])

      assert conn |> get("/admin") |> response(404)
    end

    test "honors XFF through a pinned trusted proxy", %{conn: conn} do
      original = Application.get_env(:matome_api, :admin_network)
      on_exit(fn -> Application.put_env(:matome_api, :admin_network, original) end)

      Application.put_env(:matome_api, :admin_network,
        allowlist: ["10.8.0.0/24"],
        trusted_proxies: ["127.0.0.1/32"]
      )

      # Peer is the pinned proxy (loopback), client inside the allowlist.
      conn = put_req_header(conn, "x-forwarded-for", "10.8.0.7")
      response = conn |> get("/admin") |> redirected_to()
      assert response == "/admin/login"
    end
  end

  describe "authentication gate" do
    test "GET /admin without any session redirects to login", %{conn: conn} do
      assert conn |> get("/admin") |> redirected_to() == "/admin/login"
    end

    test "a password-only (pending) session does NOT open /admin — TOTP is mandatory", %{
      conn: conn
    } do
      {user, _secret} = create_admin!()

      conn = post(conn, "/admin/login", %{"email" => user.email, "password" => @password})
      assert redirected_to(conn) == "/admin/mfa"

      # Try to skip the second factor.
      assert conn |> get("/admin") |> redirected_to() == "/admin/login"
    end

    test "a non-admin with the correct password is rejected at the first factor", %{conn: conn} do
      {user, _} = create_admin!(role: "user", enroll: false)

      conn = post(conn, "/admin/login", %{"email" => user.email, "password" => @password})

      assert redirected_to(conn) == "/admin/login"
      assert conn |> get("/admin") |> redirected_to() == "/admin/login"

      # The failure was audited (actor unknown by design — no oracle).
      assert Repo.exists?(
               from e in AuditEvent,
                 where: e.action == "admin.login_failed",
                 where: fragment("metadata->>'email' = ?", ^user.email)
             )
    end

    test "full two-factor login opens /admin and audits admin.login", %{conn: conn} do
      {user, secret} = create_admin!()

      conn = post(conn, "/admin/login", %{"email" => user.email, "password" => @password})
      assert redirected_to(conn) == "/admin/mfa"

      conn = post(conn, "/admin/mfa", %{"code" => current_code(secret)})
      assert redirected_to(conn) == "/admin"

      assert conn |> get("/admin") |> html_response(200) =~ "Admin shell"
      assert "admin.login" in audit_actions(user.id)
    end

    test "a wrong TOTP code keeps the gate shut", %{conn: conn} do
      {user, _secret} = create_admin!()

      conn = post(conn, "/admin/login", %{"email" => user.email, "password" => @password})
      conn = post(conn, "/admin/mfa", %{"code" => "000000"})

      assert redirected_to(conn) == "/admin/mfa"
      assert conn |> get("/admin") |> redirected_to() == "/admin/login"
      refute "admin.login" in audit_actions(user.id)
    end

    test "first login forces TOTP enrollment and completes it end to end", %{conn: conn} do
      {user, nil} = create_admin!(enroll: false)

      conn = post(conn, "/admin/login", %{"email" => user.email, "password" => @password})
      assert redirected_to(conn) == "/admin/mfa"

      html = conn |> get("/admin/mfa") |> html_response(200)
      assert html =~ "otpauth://totp/"

      [_, secret_base32] = Regex.run(~r|<code>([A-Z2-7]+)</code>|, html)
      secret = Base.decode32!(secret_base32, padding: false)

      conn = post(conn, "/admin/mfa", %{"code" => current_code(secret)})
      assert redirected_to(conn) == "/admin"

      assert conn |> get("/admin") |> html_response(200) =~ "Admin shell"
      assert audit_actions(user.id) == ["admin.totp_enrolled", "admin.login"]
    end

    test "an expired admin session is rejected (absolute TTL)", %{conn: conn} do
      {user, _secret} = create_admin!()
      stale = System.os_time(:second) - MatomeApiWeb.AdminAuth.session_ttl_seconds() - 1

      conn =
        Plug.Test.init_test_session(conn, %{
          "admin_user_id" => user.id,
          "admin_authenticated_at" => stale,
          "admin_totp_verified_at" => stale
        })

      assert conn |> get("/admin") |> redirected_to() == "/admin/login"
    end

    test "a session whose role was revoked mid-flight is rejected", %{conn: conn} do
      {user, _secret} = create_admin!()
      now = System.os_time(:second)

      conn =
        Plug.Test.init_test_session(conn, %{
          "admin_user_id" => user.id,
          "admin_authenticated_at" => now,
          "admin_totp_verified_at" => now
        })

      user |> Ecto.Changeset.change(role: "user") |> Repo.update!()

      assert conn |> get("/admin") |> redirected_to() == "/admin/login"
    end

    test "logout drops the session and audits", %{conn: conn} do
      {user, secret} = create_admin!()

      conn = post(conn, "/admin/login", %{"email" => user.email, "password" => @password})
      conn = post(conn, "/admin/mfa", %{"code" => current_code(secret)})
      conn = post(conn, "/admin/logout")

      assert redirected_to(conn) == "/admin/login"
      assert conn |> get("/admin") |> redirected_to() == "/admin/login"
      assert "admin.logout" in audit_actions(user.id)
    end
  end

  describe "sensitive-action re-auth (RequireRecentTotp)" do
    defp session_conn(conn, user, totp_at) do
      now = System.os_time(:second)

      conn
      |> Plug.Test.init_test_session(%{
        "admin_user_id" => user.id,
        "admin_authenticated_at" => now,
        "admin_totp_verified_at" => totp_at
      })
      |> Map.put(:request_path, "/admin/danger")
    end

    test "passes with a fresh TOTP verification", %{conn: conn} do
      {user, _} = create_admin!()
      conn = session_conn(conn, user, System.os_time(:second))

      refute MatomeApiWeb.Plugs.RequireRecentTotp.call(conn, []).halted
    end

    test "bounces a stale TOTP verification to /admin/mfa with return_to", %{conn: conn} do
      {user, _} = create_admin!()
      stale = System.os_time(:second) - MatomeApiWeb.AdminAuth.reauth_ttl_seconds() - 1
      conn = session_conn(conn, user, stale)

      conn = MatomeApiWeb.Plugs.RequireRecentTotp.call(conn, [])

      assert conn.halted
      assert redirected_to(conn) == "/admin/mfa?return_to=%2Fadmin%2Fdanger"
    end

    test "re-auth via POST /admin/mfa refreshes the stamp and audits admin.reauth", %{conn: conn} do
      {user, secret} = create_admin!()

      conn = post(conn, "/admin/login", %{"email" => user.email, "password" => @password})
      conn = post(conn, "/admin/mfa", %{"code" => current_code(secret)})
      assert redirected_to(conn) == "/admin"

      # A fresh code is only available on the NEXT timestep; use the skew
      # window: a code for the next step is valid now and not yet used.
      future_code = NimbleTOTP.verification_code(secret, time: System.os_time(:second) + 30)

      conn =
        post(conn, "/admin/mfa", %{"code" => future_code, "return_to" => "/admin/danger"})

      assert redirected_to(conn) == "/admin/danger"
      assert "admin.reauth" in audit_actions(user.id)
    end
  end
end
