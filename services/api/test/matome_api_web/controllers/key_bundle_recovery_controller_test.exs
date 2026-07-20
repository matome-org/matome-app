defmodule MatomeApiWeb.KeyBundleRecoveryControllerTest do
  @moduledoc """
  Task #1854 (plan #131 W3) — the pre-auth salt bootstrap (tracked
  carry-forward CF-1). During a "forgot password" reset the user has no
  session, so the normal authenticated `/api/keybundle` routes
  (`:auth` pipeline, Bearer access token) are unreachable. These routes
  reuse the SAME short-lived `reset` token `/api/auth/forgot-password`
  already mints (proof of email ownership) as the alternate auth channel —
  see `MatomeApiWeb.Plugs.RequireResetToken` — scoped to exactly these two
  routes and rate-limited the same way `/keybundle` is (task #1851's
  `RateLimit` plug, new `:keybundle_recovery` scope).
  """
  use MatomeApiWeb.ConnCase, async: false

  alias MatomeApi.Auth.KeyBundle
  alias MatomeApi.Repo

  @password "correct horse battery staple"

  test "unauthenticated requests (no token at all) are rejected", %{conn: conn} do
    assert %{"error" => "unauthorized"} =
             get(conn, ~p"/api/keybundle/recovery") |> json_response(401)

    assert %{"error" => "unauthorized"} =
             put(conn, ~p"/api/keybundle/recovery", bundle_params()) |> json_response(401)
  end

  test "a normal session access token does NOT authenticate the recovery routes — only a reset token does",
       %{conn: conn} do
    %{conn: authed_conn} = register_conn(conn)

    assert %{"error" => "unauthorized"} =
             get(authed_conn, ~p"/api/keybundle/recovery") |> json_response(401)
  end

  test "a valid reset token can read then rotate the caller's key bundle", %{conn: conn} do
    email = unique_email()
    %{conn: authed_conn} = register_conn(conn, email)

    original = bundle_params()
    put(authed_conn, ~p"/api/keybundle", original) |> json_response(200)

    reset_token = request_reset_token(email)
    recovery_conn = with_reset_token(with_unique_ip(build_conn()), reset_token)

    get_body = get(recovery_conn, ~p"/api/keybundle/recovery") |> json_response(200)
    assert get_body["key_bundle"]["salt_rec"] == original["salt_rec"]
    assert get_body["key_bundle"]["wrapped_dek_recovery"] == original["wrapped_dek_recovery"]

    rotated = bundle_params()
    refute rotated["wrapped_dek_recovery"] == original["wrapped_dek_recovery"]

    put_body =
      put(recovery_conn, ~p"/api/keybundle/recovery", rotated) |> json_response(200)

    assert put_body["key_bundle"]["wrapped_dek_recovery"] == rotated["wrapped_dek_recovery"]

    # Upsert in place — never a second row for the same user.
    assert Repo.aggregate(KeyBundle, :count) == 1

    # The old recovery code's server-side blob is gone — a subsequent GET
    # (same reset token, still within its ttl) reflects ONLY the rotated
    # bundle, never the original.
    final = get(recovery_conn, ~p"/api/keybundle/recovery") |> json_response(200)
    assert final["key_bundle"]["wrapped_dek_recovery"] == rotated["wrapped_dek_recovery"]
    refute final["key_bundle"]["wrapped_dek_recovery"] == original["wrapped_dek_recovery"]
  end

  test "authz: a reset token only ever resolves to its own account's bundle", %{conn: conn} do
    owner_email = unique_email()
    %{conn: owner_authed} = register_conn(conn, owner_email)
    put(owner_authed, ~p"/api/keybundle", bundle_params()) |> json_response(200)

    %{conn: other_authed} = register_conn(build_conn())
    other_params = bundle_params()
    put(other_authed, ~p"/api/keybundle", other_params) |> json_response(200)

    owner_reset_token = request_reset_token(owner_email)
    owner_recovery_conn = with_reset_token(with_unique_ip(build_conn()), owner_reset_token)

    owner_body = get(owner_recovery_conn, ~p"/api/keybundle/recovery") |> json_response(200)

    refute owner_body["key_bundle"]["wrapped_dek_recovery"] ==
             other_params["wrapped_dek_recovery"]

    assert Repo.aggregate(KeyBundle, :count) == 2
  end

  test "rate-limit/lockout: repeated recovery GET calls trip a 429 for that account", %{
    conn: conn
  } do
    email = unique_email()
    %{conn: authed_conn} = register_conn(conn, email)
    put(authed_conn, ~p"/api/keybundle", bundle_params()) |> json_response(200)

    reset_token = request_reset_token(email)
    recovery_conn = with_reset_token(with_unique_ip(build_conn()), reset_token)

    # Per-user limit is 5/min (see router.ex :keybundle_recovery_rate_limit).
    statuses = for _ <- 1..8, do: get(recovery_conn, ~p"/api/keybundle/recovery").status

    assert 200 in statuses
    assert 429 in statuses
  end

  defp register_conn(conn, email \\ nil) do
    email = email || unique_email()

    register_conn =
      post(with_unique_ip(conn), ~p"/api/auth/register", %{email: email, password: @password})

    %{"access_token" => access_token, "user" => user} = json_response(register_conn, 201)

    %{
      conn: build_conn() |> put_req_header("authorization", "Bearer #{access_token}"),
      user: user,
      email: email
    }
  end

  defp with_reset_token(conn, token) do
    put_req_header(conn, "authorization", "Bearer #{token}")
  end

  # Drives the real forgot-password flow and extracts the reset code from the
  # captured email body (Swoosh test adapter) — mirrors
  # AuthControllerTest.request_reset_token/1.
  defp request_reset_token(email) do
    post(with_unique_ip(build_conn()), ~p"/api/auth/forgot-password", %{email: email})
    assert_received {:email, sent}
    [token] = Regex.run(~r/[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/, sent.text_body)
    token
  end

  # A unique-per-call synthetic remote_ip so these register/forgot-password
  # calls don't contribute to the shared 127.0.0.1 :auth_rate_limit :ip
  # bucket every other Phoenix.ConnTest conn in the suite uses (that limiter
  # is backed by a process-lifetime ETS table with no per-test reset — see
  # the identical helper + comment in auth_controller_test.exs).
  #
  # CF-2 (task #1857, plan #131 W5): also applied to the `recovery_conn` /
  # `owner_recovery_conn` built for the actual GET/PUT /keybundle/recovery
  # calls under test — those hit the SEPARATE `:keybundle_recovery` scope's
  # `:ip` check (router.ex), which shares the exact same
  # never-reset-between-tests ETS table. Without this, aggregate GET
  # /keybundle/recovery volume across every test in this file could trip a
  # stray 429 on a test expecting 200 (a real, previously observed flake).
  defp with_unique_ip(conn) do
    n = System.unique_integer([:positive, :monotonic])
    %{conn | remote_ip: {203, 0, rem(div(n, 256), 256), rem(n, 256)}}
  end

  defp unique_email do
    "user-#{System.unique_integer([:positive])}@example.com"
  end

  defp bundle_params do
    %{
      "wrapped_dek_pw" => Base.encode64(:crypto.strong_rand_bytes(64)),
      "wrapped_dek_recovery" => Base.encode64(:crypto.strong_rand_bytes(64)),
      "salt_enc" => Base.encode64(:crypto.strong_rand_bytes(16)),
      "salt_rec" => Base.encode64(:crypto.strong_rand_bytes(16)),
      "salt_auth" => Base.encode64(:crypto.strong_rand_bytes(16)),
      "kdf_params" => %{
        "profile" => "argon2id-v1-portable",
        "algorithm" => "argon2id",
        "version" => 19,
        "memory_kib" => 19456,
        "iterations" => 2,
        "parallelism" => 1,
        "output_len" => 32
      }
    }
  end
end
