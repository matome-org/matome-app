defmodule MatomeApiWeb.Plugs.RequireAuthRevocationTest do
  @moduledoc """
  Per-request revocation through the real `:auth` pipeline (W5 #1873):
  RequireAuth → Auth.verify_access_token → TokenAllowlist, exercised over
  `GET /api/auth/me` in each enforcement mode.
  """

  # async: false — mutates the TokenAllowlist config and the global ETS cache.
  use MatomeApiWeb.ConnCase, async: false

  import ExUnit.CaptureLog

  alias MatomeApi.Auth
  alias MatomeApi.Auth.TokenAllowlist

  @password "correct horse battery staple"

  setup do
    TokenAllowlist.reset()
    :ok
  end

  describe "mode :off (default — dark)" do
    test "a revoked session's access token is still accepted", %{conn: conn} do
      %{access_token: access_token, refresh_token: refresh_token} = register()
      :ok = Auth.logout(refresh_token)

      conn = authed_get(conn, access_token)
      assert json_response(conn, 200)["user"]
    end
  end

  describe "mode :shadow" do
    test "a revoked session's access token is accepted but the denial is logged", %{conn: conn} do
      put_mode(:shadow)
      %{access_token: access_token, refresh_token: refresh_token} = register()
      :ok = Auth.logout(refresh_token)

      log =
        capture_log(fn ->
          conn = authed_get(conn, access_token)
          assert json_response(conn, 200)["user"]
        end)

      assert log =~ "token_allowlist shadow"
      assert log =~ "revoked"
    end

    test "a lookup failure is logged but never rejects", %{conn: conn} do
      put_mode(:shadow)
      put_config(lookup: fn _ -> raise DBConnection.ConnectionError, "db down" end)
      %{access_token: access_token} = register()

      log =
        capture_log(fn ->
          conn = authed_get(conn, access_token)
          assert json_response(conn, 200)["user"]
        end)

      assert log =~ "unavailable"
    end
  end

  describe "mode :enforce" do
    test "char-test: logout 401s the next request within the access-token TTL", %{conn: conn} do
      put_mode(:enforce)
      %{access_token: access_token, refresh_token: refresh_token} = register()

      # The token authenticates before revocation...
      assert json_response(authed_get(conn, access_token), 200)["user"]

      :ok = Auth.logout(refresh_token)

      # ...and the very next request with the SAME still-unexpired JWT 401s.
      conn = authed_get(build_conn(), access_token)
      assert json_response(conn, 401) == %{"error" => "unauthorized"}
    end

    test "an access token without a session binding (no sid claim) is rejected", %{conn: conn} do
      put_mode(:enforce)
      %{user: user} = register()

      {:ok, unbound_token, _claims} =
        MatomeApi.Auth.Guardian.encode_and_sign(user, %{},
          token_type: "access",
          ttl: {15, :minutes}
        )

      conn = authed_get(conn, unbound_token)
      assert json_response(conn, 401) == %{"error" => "unauthorized"}
    end

    test "fail-closed: a lookup failure rejects rather than bypasses", %{conn: conn} do
      put_mode(:enforce)
      %{access_token: access_token} = register()
      put_config(lookup: fn _ -> raise DBConnection.ConnectionError, "db down" end)

      log =
        capture_log(fn ->
          conn = authed_get(conn, access_token)
          assert json_response(conn, 401) == %{"error" => "unauthorized"}
        end)

      assert log =~ "fail-closed"
    end

    test "no-cache revert path: revocation is immediate without invalidation", %{conn: conn} do
      put_mode(:enforce)
      put_config(cache: false)
      %{access_token: access_token, refresh_token: refresh_token} = register()

      assert json_response(authed_get(conn, access_token), 200)["user"]
      :ok = Auth.logout(refresh_token)
      assert json_response(authed_get(build_conn(), access_token), 401)
    end

    test "socket connect also refuses a revoked session" do
      put_mode(:enforce)
      %{access_token: access_token, refresh_token: refresh_token} = register()

      assert {:ok, _socket} = socket_connect(access_token)

      :ok = Auth.logout(refresh_token)

      assert :error = socket_connect(access_token)
    end
  end

  defp socket_connect(token) do
    # UserSocket.connect/3 is exercised directly (rather than via the
    # Phoenix.ChannelTest.connect/2 macro, whose name collides with
    # Phoenix.ConnTest.connect/2 imported by ConnCase).
    case MatomeApiWeb.UserSocket.connect(
           %{"token" => token},
           %Phoenix.Socket{endpoint: MatomeApiWeb.Endpoint},
           %{}
         ) do
      {:ok, socket} -> {:ok, socket}
      :error -> :error
    end
  end

  defp authed_get(conn, token) do
    conn
    |> put_req_header("authorization", "Bearer " <> token)
    |> get(~p"/api/auth/me")
  end

  defp register do
    email = "user-#{System.unique_integer([:positive])}@example.com"
    {:ok, result} = Auth.register_user(%{"email" => email, "password" => @password})
    result
  end

  defp put_mode(mode), do: put_config(mode: mode)

  defp put_config(overrides) do
    original = Application.get_env(:matome_api, TokenAllowlist, [])
    Application.put_env(:matome_api, TokenAllowlist, Keyword.merge(original, overrides))
    on_exit(fn -> Application.put_env(:matome_api, TokenAllowlist, original) end)
  end
end
