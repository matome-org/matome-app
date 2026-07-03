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
  """
  def check(key, limit, window_ms, lockout_ms \\ nil)
      when is_integer(limit) and is_integer(window_ms) do
    lockout_ms = lockout_ms || window_ms
    ensure_table()
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
        :ets.new(@table, [:named_table, :public, :set, write_concurrency: true])

      _ ->
        :ok
    end
  end
end
