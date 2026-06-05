defmodule MatomeApiWeb.AuthControllerTest do
  use MatomeApiWeb.ConnCase, async: true

  @password "correct horse battery staple"

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

  defp unique_email do
    "user-#{System.unique_integer([:positive])}@example.com"
  end
end
