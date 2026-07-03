defmodule MatomeApiWeb.AuthControllerTest do
  use MatomeApiWeb.ConnCase, async: true

  import Swoosh.TestAssertions

  @password "correct horse battery staple"
  @new_password "a brand new battery staple"

  test "register returns access and refresh tokens", %{conn: conn} do
    conn = post(conn, ~p"/api/auth/register", %{email: unique_email(), password: @password})
    body = json_response(conn, 201)

    assert body["user"]["email"] =~ "@example.com"
    assert is_binary(body["access_token"])
    assert is_binary(body["refresh_token"])
    assert body["token_type"] == "Bearer"
  end

  test "login returns tokens for registered credentials", %{conn: conn} do
    email = unique_email()
    post(conn, ~p"/api/auth/register", %{email: email, password: @password})

    conn = post(build_conn(), ~p"/api/auth/login", %{email: email, password: @password})
    body = json_response(conn, 200)

    assert body["user"]["email"] == email
    assert is_binary(body["access_token"])
    assert is_binary(body["refresh_token"])
  end

  test "protected endpoint rejects missing token and accepts valid token", %{conn: conn} do
    assert %{"error" => "unauthorized"} = get(conn, ~p"/api/auth/me") |> json_response(401)

    register_conn =
      post(build_conn(), ~p"/api/auth/register", %{email: unique_email(), password: @password})

    %{"access_token" => access_token, "user" => %{"email" => email}} =
      json_response(register_conn, 201)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{access_token}")
      |> get(~p"/api/auth/me")

    assert %{"user" => %{"email" => ^email}} = json_response(conn, 200)
  end

  test "refresh rotates tokens and rejects reused refresh token", %{conn: conn} do
    register_conn =
      post(conn, ~p"/api/auth/register", %{email: unique_email(), password: @password})

    %{"refresh_token" => old_refresh_token} = json_response(register_conn, 201)

    refresh_conn = post(build_conn(), ~p"/api/auth/refresh", %{refresh_token: old_refresh_token})

    %{"access_token" => access_token, "refresh_token" => new_refresh_token} =
      json_response(refresh_conn, 200)

    assert access_token != ""
    assert new_refresh_token != old_refresh_token

    reused_conn = post(build_conn(), ~p"/api/auth/refresh", %{refresh_token: old_refresh_token})
    assert %{"error" => "invalid_refresh_token"} = json_response(reused_conn, 401)
  end

  test "logout revokes the provided refresh token", %{conn: conn} do
    register_conn =
      post(conn, ~p"/api/auth/register", %{email: unique_email(), password: @password})

    %{"refresh_token" => refresh_token} = json_response(register_conn, 201)

    assert logout_conn = post(build_conn(), ~p"/api/auth/logout", %{refresh_token: refresh_token})
    assert response(logout_conn, 204) == ""

    refresh_conn = post(build_conn(), ~p"/api/auth/refresh", %{refresh_token: refresh_token})
    assert %{"error" => "invalid_refresh_token"} = json_response(refresh_conn, 401)
  end

  test "forgot-password always returns ok and does not leak account existence", %{conn: conn} do
    known = unique_email()
    post(conn, ~p"/api/auth/register", %{email: known, password: @password})

    # Known email: 200 + a reset email is sent.
    known_conn = post(build_conn(), ~p"/api/auth/forgot-password", %{email: known})
    assert %{"status" => "ok"} = json_response(known_conn, 200)
    assert_email_sent(subject: "Reset your Matome password")

    # Unknown email: identical 200, no email sent.
    unknown_conn =
      post(build_conn(), ~p"/api/auth/forgot-password", %{email: unique_email()})

    assert %{"status" => "ok"} = json_response(unknown_conn, 200)
    assert_no_email_sent()
  end

  test "forgot-password requires an email", %{conn: conn} do
    assert %{"error" => "email_required"} =
             post(conn, ~p"/api/auth/forgot-password", %{}) |> json_response(422)
  end

  test "reset-password sets a new password and issues a session", %{conn: conn} do
    email = unique_email()
    post(conn, ~p"/api/auth/register", %{email: email, password: @password})

    token = request_reset_token(email)

    reset_conn =
      post(build_conn(), ~p"/api/auth/reset-password", %{token: token, password: @new_password})

    body = json_response(reset_conn, 200)
    assert body["user"]["email"] == email
    assert is_binary(body["access_token"])

    # The old password no longer works; the new one does.
    assert %{"error" => "invalid_credentials"} =
             post(build_conn(), ~p"/api/auth/login", %{email: email, password: @password})
             |> json_response(401)

    assert post(build_conn(), ~p"/api/auth/login", %{email: email, password: @new_password})
           |> json_response(200)
  end

  test "reset-password rejects an invalid token", %{conn: conn} do
    assert %{"error" => "invalid_reset_token"} =
             post(conn, ~p"/api/auth/reset-password", %{
               token: "not-a-token",
               password: @new_password
             })
             |> json_response(422)
  end

  test "reset-password rejects a too-short password", %{conn: conn} do
    email = unique_email()
    post(conn, ~p"/api/auth/register", %{email: email, password: @password})
    token = request_reset_token(email)

    body =
      post(build_conn(), ~p"/api/auth/reset-password", %{token: token, password: "short"})
      |> json_response(422)

    assert body["errors"]["password"]
  end

  # Drives the real forgot-password flow and extracts the reset code from the
  # captured email body (Swoosh test adapter), mirroring what a user does.
  defp request_reset_token(email) do
    post(build_conn(), ~p"/api/auth/forgot-password", %{email: email})
    # Swoosh's Test adapter delivers by messaging the caller process.
    assert_received {:email, sent}
    [token] = Regex.run(~r/[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/, sent.text_body)
    token
  end

  defp unique_email do
    "user-#{System.unique_integer([:positive])}@example.com"
  end
end
