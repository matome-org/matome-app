defmodule MatomeApi.RateLimiterTest do
  use ExUnit.Case, async: true

  alias MatomeApi.RateLimiter

  test "allows requests while under the limit" do
    key = make_ref()
    assert :ok = RateLimiter.check(key, 3, 60_000)
    assert :ok = RateLimiter.check(key, 3, 60_000)
    assert :ok = RateLimiter.check(key, 3, 60_000)
  end

  test "locks out once the limit is exceeded and stays locked for the next call" do
    key = make_ref()
    assert :ok = RateLimiter.check(key, 2, 60_000, 60_000)
    assert :ok = RateLimiter.check(key, 2, 60_000, 60_000)
    assert {:error, :locked} = RateLimiter.check(key, 2, 60_000, 60_000)

    # Still locked on the very next call even though, counted alone, it would
    # be within the window's count again after a naive reset — this is what
    # distinguishes a lockout from a bare windowed counter.
    assert {:error, :locked} = RateLimiter.check(key, 2, 60_000, 60_000)
  end

  test "independent keys never affect each other" do
    key_a = make_ref()
    key_b = make_ref()

    assert :ok = RateLimiter.check(key_a, 1, 60_000, 60_000)
    assert {:error, :locked} = RateLimiter.check(key_a, 1, 60_000, 60_000)

    assert :ok = RateLimiter.check(key_b, 1, 60_000, 60_000)
  end
end
