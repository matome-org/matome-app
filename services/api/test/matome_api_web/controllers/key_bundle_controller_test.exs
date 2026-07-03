defmodule MatomeApiWeb.KeyBundleControllerTest do
  use MatomeApiWeb.ConnCase, async: false

  alias MatomeApi.Auth.KeyBundle
  alias MatomeApi.Repo

  @password "correct horse battery staple"

  test "unauthenticated requests are rejected", %{conn: conn} do
    assert %{"error" => "unauthorized"} = get(conn, ~p"/api/keybundle") |> json_response(401)

    assert %{"error" => "unauthorized"} =
             put(conn, ~p"/api/keybundle", bundle_params()) |> json_response(401)
  end

  test "GET returns 404 before any bundle has been stored", %{conn: conn} do
    %{conn: conn} = register_conn(conn)

    assert %{"error" => "not_found"} = get(conn, ~p"/api/keybundle") |> json_response(404)
  end

  test "PUT upserts the caller's bundle and GET returns exactly what was stored", %{conn: conn} do
    %{conn: conn} = register_conn(conn)
    params = bundle_params()

    put_body = put(conn, ~p"/api/keybundle", params) |> json_response(200)
    assert put_body["key_bundle"]["wrapped_dek_pw"] == params["wrapped_dek_pw"]

    get_body = get(conn, ~p"/api/keybundle") |> json_response(200)
    assert get_body["key_bundle"] == put_body["key_bundle"]

    # A second PUT (e.g. password change re-wrap) replaces the bundle in place
    # rather than creating a second row — upsert, not insert-only.
    new_params = bundle_params()
    refute new_params["wrapped_dek_pw"] == params["wrapped_dek_pw"]

    put(conn, ~p"/api/keybundle", new_params) |> json_response(200)
    final_body = get(conn, ~p"/api/keybundle") |> json_response(200)
    assert final_body["key_bundle"]["wrapped_dek_pw"] == new_params["wrapped_dek_pw"]
    assert Repo.aggregate(KeyBundle, :count) == 1
  end

  test "PUT rejects a bundle missing required opaque fields", %{conn: conn} do
    %{conn: conn} = register_conn(conn)

    body =
      put(conn, ~p"/api/keybundle", %{"wrapped_dek_pw" => "only-one-field"})
      |> json_response(422)

    assert body["errors"]["salt_enc"]
  end

  test "authz: a second user can never read or overwrite another user's bundle", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    %{conn: other_conn} = register_conn(build_conn())

    owner_params = bundle_params()
    put(owner_conn, ~p"/api/keybundle", owner_params) |> json_response(200)

    # The other user has no bundle of their own — never the owner's.
    assert %{"error" => "not_found"} = get(other_conn, ~p"/api/keybundle") |> json_response(404)

    # The other user PUTting their own bundle must never touch the owner's row.
    other_params = bundle_params()
    put(other_conn, ~p"/api/keybundle", other_params) |> json_response(200)

    owner_body = get(owner_conn, ~p"/api/keybundle") |> json_response(200)
    assert owner_body["key_bundle"]["wrapped_dek_pw"] == owner_params["wrapped_dek_pw"]

    other_body = get(other_conn, ~p"/api/keybundle") |> json_response(200)
    assert other_body["key_bundle"]["wrapped_dek_pw"] == other_params["wrapped_dek_pw"]

    assert Repo.aggregate(KeyBundle, :count) == 2
  end

  test "opaque-only: the server stores and returns the wrapped blobs verbatim, never derives from them",
       %{conn: conn} do
    %{conn: conn, user: user} = register_conn(conn)
    params = bundle_params()

    put(conn, ~p"/api/keybundle", params) |> json_response(200)

    # Read the raw DB row directly (bypassing the controller/JSON layer) and
    # assert the persisted bytes are byte-identical to what the (simulated)
    # client sent — the server never decoded, re-derived, or otherwise
    # transformed the opaque blobs. It is architecturally incapable of
    # unwrapping them: no KEK/DEK ever appears in this codepath, only base64
    # ciphertext the client generated client-side.
    stored = Repo.get_by!(KeyBundle, user_id: user["id"])
    assert stored.wrapped_dek_pw == params["wrapped_dek_pw"]
    assert stored.wrapped_dek_recovery == params["wrapped_dek_recovery"]
    assert stored.salt_enc == params["salt_enc"]
    assert stored.salt_rec == params["salt_rec"]
    assert stored.salt_auth == params["salt_auth"]
    assert stored.kdf_params == params["kdf_params"]

    # The GET response is the same opaque echo — no field is dropped,
    # re-encoded, or supplemented with anything derived server-side.
    get_body = get(conn, ~p"/api/keybundle") |> json_response(200)
    assert get_body["key_bundle"]["wrapped_dek_pw"] == params["wrapped_dek_pw"]
    assert get_body["key_bundle"]["wrapped_dek_recovery"] == params["wrapped_dek_recovery"]
  end

  test "rate-limit/lockout: repeated GET /keybundle calls trip a 429 for that account", %{
    conn: conn
  } do
    %{conn: conn} = register_conn(conn)
    put(conn, ~p"/api/keybundle", bundle_params()) |> json_response(200)

    # The per-user limit is 10/min (see router.ex :keybundle_get_rate_limit).
    # This user is freshly registered so its counter starts at zero
    # regardless of what else the suite is doing concurrently.
    statuses = for _ <- 1..14, do: get(conn, ~p"/api/keybundle").status

    assert 200 in statuses
    assert 429 in statuses

    # Once tripped it stays tripped for the caller (lockout, not a flicker).
    assert get(conn, ~p"/api/keybundle").status == 429
  end

  defp register_conn(conn) do
    email = "user-#{System.unique_integer([:positive])}@example.com"

    register_conn =
      post(with_unique_ip(conn), ~p"/api/auth/register", %{email: email, password: @password})

    %{"access_token" => access_token, "user" => user} = json_response(register_conn, 201)

    %{
      conn:
        with_unique_ip(build_conn())
        |> put_req_header("authorization", "Bearer #{access_token}"),
      user: user
    }
  end

  # CF-2 (task #1857, plan #131 W5): `MatomeApi.RateLimiter` backs
  # `:keybundle_get_rate_limit`'s `:ip` check with a single process-lifetime
  # ETS table that is never reset between ExUnit tests, and
  # `Phoenix.ConnTest.build_conn/0` always hardcodes `remote_ip: {127, 0, 0,
  # 1}`. Left alone, EVERY GET /keybundle call across every test in this
  # file (not just the dedicated rate-limit test below) accumulates against
  # the SAME 127.0.0.1 IP bucket, so aggregate suite volume can trip a
  # stray 429 on a test that only expects 200 — a real, previously observed
  # flake, not hypothetical. Giving each test's conn a unique synthetic
  # remote_ip isolates its own IP-bucket from every other test's, without
  # touching `MatomeApi.RateLimiter`/`RateLimit` plug production code at
  # all (test-infra-only fix; mirrors the identical pattern already used for
  # the `:auth` scope in auth_controller_test.exs /
  # key_bundle_recovery_controller_test.exs, just not yet applied to the
  # returned *authenticated* conn that actually issues the GET/PUT
  # /keybundle calls under test).
  defp with_unique_ip(conn) do
    n = System.unique_integer([:positive, :monotonic])
    %{conn | remote_ip: {198, 51, rem(div(n, 256), 256), rem(n, 256)}}
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
