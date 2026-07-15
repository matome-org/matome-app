defmodule MatomeApiWeb.AdminAccessTest do
  @moduledoc """
  Admin email-OTP gate acceptance:

  - panel kill switch (404 when disabled);
  - non-allowlisted email → total silence (no mail, no flash, no redirect);
  - allowlisted email → OTP mail + /admin/otp → session;
  - one-shot OTP, absolute session TTL;
  - soft IP allowlist only tiers rate limits (no hard 404).
  """
  use MatomeApiWeb.ConnCase, async: false

  import Ecto.Query
  import Swoosh.TestAssertions

  alias MatomeApi.Events.Event
  alias MatomeApi.Repo
  alias MatomeApiWeb.AdminAuth

  @allowlisted "admin@example.com"

  defp allowlist!(emails) do
    original = Application.get_env(:matome_api, :admin_panel)
    on_exit(fn -> Application.put_env(:matome_api, :admin_panel, original) end)

    Application.put_env(
      :matome_api,
      :admin_panel,
      Keyword.merge(original || [], enabled: true, email_allowlist: emails)
    )
  end

  defp request_and_code!(conn, email) do
    conn = post(conn, "/admin/login", %{"email" => email})
    assert redirected_to(conn) == "/admin/otp"

    code =
      receive do
        {:email, %Swoosh.Email{} = email_msg} ->
          [_, code] = Regex.run(~r/\b(\d{6})\b/, email_msg.text_body)
          code
      after
        1_000 -> flunk("expected OTP email")
      end

    {conn, code}
  end

  defp audit_actions(email) do
    Repo.all(
      from e in Event,
        where: e.actor_email == ^email,
        order_by: e.id,
        select: e.event_key
    )
  end

  describe "panel kill switch" do
    test "rejects /admin when panel disabled", %{conn: conn} do
      original = Application.get_env(:matome_api, :admin_panel)
      on_exit(fn -> Application.put_env(:matome_api, :admin_panel, original) end)

      Application.put_env(:matome_api, :admin_panel,
        enabled: false,
        email_allowlist: [@allowlisted]
      )

      assert conn |> get("/admin") |> response(404)
      assert conn |> get("/admin/login") |> response(404)
    end
  end

  describe "soft IP allowlist" do
    test "non-allowlisted IP still reaches the login screen", %{conn: conn} do
      allowlist!([@allowlisted])
      original = Application.get_env(:matome_api, :admin_network)
      on_exit(fn -> Application.put_env(:matome_api, :admin_network, original) end)

      Application.put_env(:matome_api, :admin_network,
        allowlist: ["10.8.0.0/24"],
        trusted_proxies: []
      )

      conn = %{conn | remote_ip: {203, 0, 113, 5}}
      html = conn |> get("/admin/login") |> html_response(200)
      assert html =~ "Sign in"
    end
  end

  describe "email-OTP login" do
    setup do
      allowlist!([@allowlisted])
      :ok
    end

    test "GET /admin/login renders email-only DS form", %{conn: conn} do
      html = conn |> get("/admin/login") |> html_response(200)
      assert html =~ "matome-field__control"
      assert html =~ ~s(type="email")
      refute html =~ ~s(type="password")
      assert html =~ "Continue"
    end

    test "non-allowlisted email is total silence — no mail, no flash, no redirect", %{conn: conn} do
      conn = post(conn, "/admin/login", %{"email" => "stranger@example.com"})
      assert html_response(conn, 200) =~ "Sign in"
      refute Phoenix.Flash.get(conn.assigns.flash, :error)
      refute Phoenix.Flash.get(conn.assigns.flash, :info)
      refute_email_sent()
    end

    test "allowlisted email sends OTP and completes login", %{conn: conn} do
      {conn, code} = request_and_code!(conn, @allowlisted)

      conn = post(conn, "/admin/otp", %{"code" => code})
      assert redirected_to(conn) == "/admin"

      assert conn |> get("/admin") |> html_response(200) =~ "Admin"
      assert "security.admin.login_otp_requested.v1" in audit_actions(@allowlisted)
      assert "security.admin.login.v1" in audit_actions(@allowlisted)
    end

    test "audit records the proxy-derived client IP", %{conn: conn} do
      original = Application.get_env(:matome_api, :admin_network)
      on_exit(fn -> Application.put_env(:matome_api, :admin_network, original) end)

      Application.put_env(:matome_api, :admin_network,
        allowlist: [],
        trusted_proxies: ["172.16.0.0/16"]
      )

      conn =
        conn
        |> Map.put(:remote_ip, {172, 16, 0, 10})
        |> put_req_header("x-forwarded-for", "198.51.100.77")

      {_conn, _code} = request_and_code!(conn, @allowlisted)

      event =
        Repo.one!(
          from e in Event,
            where: e.event_key == "security.admin.login_otp_requested.v1"
        )

      assert event.remote_ip == "198.51.100.77"
    end

    test "OTP is one-shot — reuse fails", %{conn: conn} do
      {conn, code} = request_and_code!(conn, @allowlisted)

      conn = post(conn, "/admin/otp", %{"code" => code})
      assert redirected_to(conn) == "/admin"

      {conn, _fresh} = request_and_code!(conn, @allowlisted)
      conn = post(conn, "/admin/otp", %{"code" => code})
      assert redirected_to(conn) =~ "/admin/otp"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Invalid"
    end

    test "wrong OTP audits login_failed and stays on otp", %{conn: conn} do
      {conn, _code} = request_and_code!(conn, @allowlisted)
      conn = post(conn, "/admin/otp", %{"code" => "000000"})
      assert redirected_to(conn) =~ "/admin/otp"
      assert "security.admin.login_failed.v1" in audit_actions(@allowlisted)
    end

    test "expired admin session is rejected", %{conn: conn} do
      stale = System.os_time(:second) - AdminAuth.session_ttl_seconds() - 1

      conn =
        Plug.Test.init_test_session(conn, %{
          "admin_email" => @allowlisted,
          "admin_authenticated_at" => stale,
          "admin_otp_verified_at" => stale
        })

      assert conn |> get("/admin") |> redirected_to() == "/admin/login"
    end

    test "session whose email was removed from allowlist mid-flight is rejected", %{conn: conn} do
      now = System.os_time(:second)

      conn =
        Plug.Test.init_test_session(conn, %{
          "admin_email" => @allowlisted,
          "admin_authenticated_at" => now,
          "admin_otp_verified_at" => now
        })

      allowlist!(["other@example.com"])
      assert conn |> get("/admin") |> redirected_to() == "/admin/login"
    end

    test "no users row is required", %{conn: conn} do
      {conn, code} = request_and_code!(conn, @allowlisted)
      conn = post(conn, "/admin/otp", %{"code" => code})
      assert redirected_to(conn) == "/admin"
      assert conn |> get("/admin") |> html_response(200) =~ "Admin"
    end
  end

  describe "OTP freshness" do
    test "recent_otp?/1 enforces the reauth window" do
      stale = System.os_time(:second) - AdminAuth.reauth_ttl_seconds() - 1
      refute AdminAuth.recent_otp?(%{"admin_otp_verified_at" => stale})
      assert AdminAuth.recent_otp?(%{"admin_otp_verified_at" => System.os_time(:second)})
    end
  end
end
