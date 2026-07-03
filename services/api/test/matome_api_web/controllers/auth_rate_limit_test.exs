defmodule MatomeApiWeb.AuthRateLimitTest do
  use MatomeApiWeb.ConnCase, async: false

  @password "correct horse battery staple"
  @wrong_password "definitely not it"

  # Defense against offline-crackable-envelope credential-stuffing: repeated
  # login attempts against a single account must eventually lock out,
  # independent of the per-IP limit. Uses a fresh, unique email so its
  # per-account counter starts at zero regardless of what the rest of the
  # (concurrently-running) suite is doing on the shared per-IP bucket.
  test "repeated login attempts against one account trip a 429 lockout", %{conn: conn} do
    email = "lockout-#{System.unique_integer([:positive])}@example.com"
    post(conn, ~p"/api/auth/register", %{email: email, password: @password})

    # Per-account limit is 5/min (see router.ex :auth_rate_limit).
    statuses =
      for _ <- 1..8 do
        post(build_conn(), ~p"/api/auth/login", %{email: email, password: @wrong_password}).status
      end

    assert 429 in statuses

    # Locked out even for the *correct* password — that is the point of an
    # account lockout defending against credential stuffing.
    assert post(build_conn(), ~p"/api/auth/login", %{email: email, password: @password}).status ==
             429
  end
end
