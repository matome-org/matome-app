defmodule MatomeApi.AuthTest do
  use MatomeApi.DataCase, async: true

  alias MatomeApi.Auth

  @password "correct horse battery staple"

  describe "login/2 user-enumeration timing hardening (okt-audit AUDIT-CORE, task #1865)" do
    test "wrong password for a real account returns :invalid_credentials" do
      email = unique_email()
      {:ok, _auth} = Auth.register_user(%{"email" => email, "password" => @password})

      assert Auth.login(email, "definitely not it") == {:error, :invalid_credentials}
    end

    test "a nonexistent email returns the same error shape as a wrong password" do
      assert Auth.login(unique_email(), "whatever") == {:error, :invalid_credentials}
    end

    test "both the real-account and no-such-account branches pay comparable Argon2 cost" do
      email = unique_email()
      {:ok, _auth} = Auth.register_user(%{"email" => email, "password" => @password})

      # Warm up the Argon2 NIF/scheduler once before timing so a one-off JIT
      # /first-call cost doesn't skew the very first measurement.
      Auth.login(email, "warmup")

      {existing_us, {:error, :invalid_credentials}} =
        :timer.tc(fn -> Auth.login(email, "definitely not it") end)

      {missing_us, {:error, :invalid_credentials}} =
        :timer.tc(fn -> Auth.login(unique_email(), "whatever") end)

      # Not a tight timing-attack assertion (inherently flaky under CI
      # scheduling jitter) — just a coarse regression guard that the
      # no-such-account branch isn't a near-instant short-circuit anymore.
      # Before this fix it returned in a small fraction of the hashed
      # branch's time (no Argon2 call at all); now both call into Argon2
      # once, so neither should be more than ~3x faster than the other.
      assert missing_us > existing_us / 3
      assert existing_us > missing_us / 3
    end
  end

  defp unique_email do
    "user-#{System.unique_integer([:positive])}@example.com"
  end
end
