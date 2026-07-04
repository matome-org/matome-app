defmodule MatomeApi.RateLimiter.Supervisor do
  @moduledoc """
  Dedicated `:rest_for_one` supervisor pairing `MatomeApi.RateLimiter.TableHeir`
  with `MatomeApi.RateLimiter` (okt-audit PASS-2 FINDING-3, task #1867,
  verdict pinned on #1857).

  ## The gap this closes

  Both children used to sit directly in the top-level application
  supervisor (`MatomeApi.Application`), which runs `:one_for_one` — every
  child is restarted independently, in isolation. That is correct for most
  of the tree, but wrong for this specific pair: `TableHeir`'s only job is
  to be the ETS table's `heir:` (see `table_heir.ex` / `rate_limiter.ex`),
  and that heir `pid()` is captured into the table's options once, at
  `:ets.new/2` time — it is NOT live-updated if `TableHeir` later crashes
  and gets a fresh pid from its own restart.

  Under plain `:one_for_one`, that produces exactly the scenario
  okt-audit PASS-2 named: `TableHeir` crashes and restarts (new pid) while
  `RateLimiter` keeps running untouched — the ETS table's `heir:` field
  still points at the OLD, now-dead `TableHeir` pid. If `RateLimiter`
  itself crashes ANY time after that (even much later), ETS finds the
  heir field points at a dead process and DESTROYS the table instead of
  transferring it — silently wiping every counter/lockout, the exact
  failure #1865 introduced this heir mechanism to prevent in the first
  place.

  ## The fix

  `:rest_for_one` restarts the crashed child AND every child started
  AFTER it (in this 2-element list, that's `RateLimiter` when `TableHeir`
  is what crashed). Concretely: when `TableHeir` crashes, this supervisor
  ALSO force-terminates the still-running `RateLimiter` before restarting
  both. That forced termination runs while the ETS table's heir field is
  still the just-died `TableHeir` pid, so ETS destroys the table right
  then (empty counters, not a security issue — see `rate_limiter.ex`'s
  moduledoc, `:public`+atomic updates mean no in-flight request data is
  ever exclusively held by the GenServer). The freshly-restarted
  `RateLimiter.init/1` then finds no existing table (`:ets.whereis` ==
  `:undefined`) and creates a BRAND NEW one, capturing the CURRENT (live,
  freshly-restarted) `TableHeir` pid as `heir:`. The stale-heir window is
  thus bounded to "however long the cascade restart takes", not
  "indefinitely until RateLimiter happens to also restart for an
  unrelated reason" — closing the gap without any unsafe attempt to call
  `:ets.setopts/2` from a process that isn't the table's current owner
  (verified: `setopts/2` requires the calling process to BE the owner,
  which after a heir hand-off is `TableHeir`, not `RateLimiter` — so
  `RateLimiter` re-asserting the heir option from its own `init/1` would
  itself raise `ArgumentError` on the exact "table already exists" path
  that #1865 depends on).

  A `RateLimiter`-only crash is unaffected: nothing is listed AFTER it in
  this supervisor, so `:rest_for_one` restarts ONLY `RateLimiter` — the
  original #1865 heir hand-off (table survives via the still-alive,
  untouched `TableHeir`) behaves exactly as before. See
  `test/matome_api/rate_limiter_crash_test.exs` for both scenarios.
  """
  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Must start first — see `MatomeApi.RateLimiter.table_heir/0`, which
      # looks up this process's pid to pass as the ETS `heir:` option when
      # `RateLimiter.init/1` creates the table.
      MatomeApi.RateLimiter.TableHeir,
      MatomeApi.RateLimiter
    ]

    # :rest_for_one (not :one_for_one) is the load-bearing choice here —
    # see the moduledoc's "The fix" section.
    #
    # max_restarts/max_seconds raised well above the library default (3
    # restarts / 5 seconds): the whole POINT of this pairing is to survive
    # repeated crashes gracefully (crash -> cascade -> fresh table+heir ->
    # crash again -> hand off cleanly, indefinitely). Under a `:rest_for_one`
    # cascade every single TableHeir crash counts as 2 restarts (itself +
    # RateLimiter), so the 3-line default would let a handful of TableHeir
    # crashes within 5s trip the SUPERVISOR's own restart-intensity limit —
    # tearing down and rebuilding the whole pair (losing all in-flight
    # counters/lockouts) via the parent `MatomeApi.Application` supervisor,
    # which is exactly the kind of silent, unbounded data loss this task
    # (#1867) exists to close, just one level up the tree instead of at the
    # ETS-heir level.
    Supervisor.init(children, strategy: :rest_for_one, max_restarts: 20, max_seconds: 5)
  end
end
