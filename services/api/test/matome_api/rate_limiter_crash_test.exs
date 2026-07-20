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
  alias MatomeApi.RateLimiter.TableHeir

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

  describe "FINDING-3 (#1867): TableHeir-restart resilience" do
    test "TableHeir crash cascade-restarts RateLimiter too, so the recreated " <>
           "table's heir is the CURRENT TableHeir, never a stale pid" do
      old_heir_pid = Process.whereis(TableHeir)
      old_rl_pid = Process.whereis(RateLimiter)
      assert is_pid(old_heir_pid)
      assert is_pid(old_rl_pid)

      heir_ref = Process.monitor(old_heir_pid)
      Process.exit(old_heir_pid, :kill)
      assert_receive {:DOWN, ^heir_ref, :process, ^old_heir_pid, :killed}, 1_000

      new_heir_pid = wait_until_pid_changes(fn -> Process.whereis(TableHeir) end, old_heir_pid)
      new_rl_pid = wait_until_pid_changes(fn -> Process.whereis(RateLimiter) end, old_rl_pid)
      wait_until_table_exists()

      # The cascade: RateLimiter restarted too, not just TableHeir.
      assert new_rl_pid != old_rl_pid

      # The recreated table's heir field is the CURRENT TableHeir pid, not
      # the dead pre-crash one — this is the actual gap FINDING-3 named.
      assert :ets.info(RateLimiter, :heir) == new_heir_pid
      refute :ets.info(RateLimiter, :heir) == old_heir_pid

      # End-to-end: the table still functions correctly post-cascade.
      key = make_ref()
      assert :ok = RateLimiter.check(key, 1, 60_000, 60_000)
      assert {:error, :locked} = RateLimiter.check(key, 1, 60_000, 60_000)
    end

    test "after a TableHeir-crash cascade, a SUBSEQUENT RateLimiter-only " <>
           "crash still hands the table off cleanly (gap fully closed)" do
      key = make_ref()
      assert :ok = RateLimiter.check(key, 1, 60_000, 60_000)

      # First: crash TableHeir, let the cascade settle.
      heir_pid = Process.whereis(TableHeir)
      rl_pid_before_cascade = Process.whereis(RateLimiter)
      heir_ref = Process.monitor(heir_pid)
      Process.exit(heir_pid, :kill)
      assert_receive {:DOWN, ^heir_ref, :process, ^heir_pid, :killed}, 1_000
      rl_pid_after_cascade =
        wait_until_pid_changes(
          fn -> Process.whereis(RateLimiter) end,
          rl_pid_before_cascade
        )
      wait_until_table_exists()

      # The cascade recreated the table (fresh, so the pre-cascade lockout
      # is gone) — re-establish a lockout against the NEW table.
      key2 = make_ref()
      assert :ok = RateLimiter.check(key2, 1, 60_000, 60_000)
      assert {:error, :locked} = RateLimiter.check(key2, 1, 60_000, 60_000)

      # Second: crash RateLimiter ALONE (TableHeir untouched this time) —
      # this is the original #1865 scenario, now exercised against the
      # freshly-recreated table + its freshly-correct heir.
      rl_ref = Process.monitor(rl_pid_after_cascade)
      Process.exit(rl_pid_after_cascade, :kill)
      assert_receive {:DOWN, ^rl_ref, :process, ^rl_pid_after_cascade, :killed}, 1_000

      _new_rl_pid = wait_until_restarted(rl_pid_after_cascade)

      # The table survived via heir hand-off — key2's lockout is still in
      # force, proving no data was lost on this second crash.
      assert {:error, :locked} = RateLimiter.check(key2, 1, 60_000, 60_000)
    end
  end

  defp wait_until_pid_changes(lookup, old_pid, attempts \\ 50)

  defp wait_until_pid_changes(_lookup, _old_pid, 0) do
    flunk("process did not restart with a new pid in time")
  end

  defp wait_until_pid_changes(lookup, old_pid, attempts) do
    case lookup.() do
      pid when is_pid(pid) and pid != old_pid ->
        pid

      _ ->
        Process.sleep(20)
        wait_until_pid_changes(lookup, old_pid, attempts - 1)
    end
  end

  # A GenServer's registered `name:` is bound before its `init/1` runs (see
  # `:gen.init_it/6`), so `Process.whereis(RateLimiter)` can observe the new
  # pid slightly BEFORE `ensure_table/0` has actually (re)created the ETS
  # table during a cascade restart. Poll for the table itself, not just the
  # process identity, to avoid a flaky race in the FINDING-3 tests above.
  defp wait_until_table_exists(attempts \\ 50)

  defp wait_until_table_exists(0) do
    flunk("MatomeApi.RateLimiter ETS table was not recreated in time")
  end

  defp wait_until_table_exists(attempts) do
    case :ets.whereis(RateLimiter) do
      :undefined ->
        Process.sleep(20)
        wait_until_table_exists(attempts - 1)

      _tid ->
        :ok
    end
  end
end
