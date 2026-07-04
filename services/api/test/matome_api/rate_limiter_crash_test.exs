defmodule MatomeApi.RateLimiterCrashTest do
  @moduledoc """
  Regression test for the okt-audit AUDIT-CORE ETS-ownership race (task
  #1865): `MatomeApi.RateLimiter.check/4` used to call `ensure_table/0`
  itself (from the caller/web-request process), not only at GenServer
  boot. After a GenServer crash+restart, a request process racing the
  restart could recreate the table — raising `ArgumentError` (500) on a
  concurrent creation race, and silently wiping every counter/lockout the
  instant that transient owner's process exited.

  Runs `async: false` because it deliberately kills the real, globally
  shared `MatomeApi.RateLimiter` GenServer and waits for the supervisor
  to restart it — deliberately disruptive, so it must not interleave
  with other tests' own timing-sensitive lockout assertions.
  """
  use ExUnit.Case, async: false

  alias MatomeApi.RateLimiter

  test "surviving a GenServer crash/restart keeps the ETS table alive (no 500, no silent reset)" do
    key = make_ref()

    assert :ok = RateLimiter.check(key, 1, 60_000, 60_000)
    assert {:error, :locked} = RateLimiter.check(key, 1, 60_000, 60_000)

    pid = Process.whereis(RateLimiter)
    assert is_pid(pid)
    ref = Process.monitor(pid)

    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^ref, :process, ^pid, :killed}, 1_000

    new_pid = wait_until_restarted(pid)
    assert new_pid != pid

    # The table survived the crash via ETS `heir:` hand-off to the
    # long-lived application supervisor (not recreated empty by the new
    # GenServer instance's `init/1`): the pre-crash lockout for `key` is
    # still in force, and getting here at all proves no ArgumentError/500
    # was raised racing table creation.
    assert {:error, :locked} = RateLimiter.check(key, 1, 60_000, 60_000)

    # A brand-new key proves the table is still fully writable post-restart.
    other_key = make_ref()
    assert :ok = RateLimiter.check(other_key, 1, 60_000, 60_000)
    assert {:error, :locked} = RateLimiter.check(other_key, 1, 60_000, 60_000)
  end

  defp wait_until_restarted(old_pid, attempts \\ 50)

  defp wait_until_restarted(_old_pid, 0) do
    flunk("MatomeApi.RateLimiter did not restart in time")
  end

  defp wait_until_restarted(old_pid, attempts) do
    case Process.whereis(RateLimiter) do
      pid when is_pid(pid) and pid != old_pid ->
        pid

      _ ->
        Process.sleep(20)
        wait_until_restarted(old_pid, attempts - 1)
    end
  end
end
