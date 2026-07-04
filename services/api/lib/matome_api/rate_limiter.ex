defmodule MatomeApi.RateLimiter do
  @moduledoc """
  Minimal in-house fixed-window rate-limit + lockout, backed by ETS.

  Why hand-rolled instead of `hammer`/`plug_attack`: this task was
  implemented in a sandbox with no outbound network access, so `mix
  deps.get` cannot fetch a new hex package. This module is deliberately
  small and dependency-free — a GenServer owns a public ETS table so
  counts are atomic via `:ets.update_counter/4` across concurrent
  requests, with no serialization through the GenServer's mailbox on the
  hot path.

  Two mechanisms combine to make this a *lockout*, not just a windowed
  counter: once a key exceeds `limit` attempts within `window_ms`, a
  separate lockout marker is set for `lockout_ms` and every subsequent
  call for that key is rejected until it expires — even if a naive
  window rollover would have "forgiven" the count in the meantime.

  If a maintained limiter (hammer / plug_attack) becomes fetchable later,
  this module's `check/4` call sites (see
  `MatomeApiWeb.Plugs.RateLimit`) are the only place to swap.

  ## Table ownership (okt-audit AUDIT-CORE, task #1865)

  Only this supervised GenServer ever creates the ETS table (in `init/1`).
  `check/4` — called from web-request processes — never does. It used to
  call `ensure_table/0` itself, which meant that after this GenServer
  crashed, a request process racing the supervisor's restart could
  recreate the table before `init/1` got to it: two callers racing
  `:ets.new/2` concurrently raised `ArgumentError` (surfacing as a 500
  instead of a rate decision), and — worse — a table owned by that
  transient caller process died silently (wiping every counter/lockout)
  the instant that caller's request finished and it exited.

  The table is created with `heir:` pointing at
  `MatomeApi.RateLimiter.TableHeir`, a dedicated do-nothing process started
  earlier in the supervision tree specifically to survive this GenServer's
  restarts. If this GenServer crashes, ETS transfers table ownership to
  that heir instead of destroying the table, so counts/lockouts survive
  the crash+restart window with zero gap — being `:public`, reads/writes
  never depended on who currently "owns" the table anyway. `init/1`'s
  `ensure_table/0` then finds the already-alive table via `:ets.whereis/1`
  and leaves it alone.
  """
  use GenServer

  @table __MODULE__

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    ensure_table()
    {:ok, %{}}
  end

  @doc """
  Records one attempt for `key`.

  Returns `:ok` while the count for `key` is at or under `limit` within
  the current `window_ms` bucket. Once the count exceeds `limit`, `key`
  is locked out for `lockout_ms` (defaults to `window_ms`) and every call
  — regardless of whether a fresh window would otherwise reset the count
  — returns `{:error, :locked}` until the lockout expires.

  Assumes the table already exists (created by this module's supervised
  GenServer at boot — see the moduledoc). Deliberately does NOT call
  `ensure_table/0` itself: this runs in the caller's (web-request)
  process, and only the GenServer may create/own the table.
  """
  def check(key, limit, window_ms, lockout_ms \\ nil)
      when is_integer(limit) and is_integer(window_ms) do
    lockout_ms = lockout_ms || window_ms
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@table, {:lockout, key}) do
      [{_, locked_until}] when locked_until > now ->
        {:error, :locked}

      _ ->
        window = div(now, window_ms)
        count_key = {:count, key, window}
        count = :ets.update_counter(@table, count_key, {2, 1}, {count_key, 0})

        if count > limit do
          :ets.insert(@table, {{:lockout, key}, now + lockout_ms})
          {:error, :locked}
        else
          :ok
        end
    end
  end

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined ->
        opts = [:named_table, :public, :set, {:write_concurrency, true}, table_heir()]

        try do
          :ets.new(@table, opts)
        rescue
          # Defensive belt-and-suspenders: only reachable if two GenServer
          # inits somehow race each other (normal one_for_one supervision
          # never runs two instances at once). `:ets.new/2` raises
          # `ArgumentError` when a `:named_table` with this name already
          # exists — treat that identically to the `:ets.whereis/1` hit
          # above instead of crashing the caller.
          ArgumentError -> :ok
        end

      _ ->
        :ok
    end
  end

  # `self()` can't be its own heir (it's already gone by the time a crash
  # would trigger hand-off), so we point at the dedicated
  # `MatomeApi.RateLimiter.TableHeir` process instead — started earlier in
  # the supervision tree (see application.ex) specifically to accept this
  # hand-off and do nothing with it.
  defp table_heir do
    case Process.whereis(MatomeApi.RateLimiter.TableHeir) do
      pid when is_pid(pid) -> {:heir, pid, :rate_limiter_table}
      _ -> {:heir, :none}
    end
  end
end
