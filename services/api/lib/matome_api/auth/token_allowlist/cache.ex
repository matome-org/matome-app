defmodule MatomeApi.Auth.TokenAllowlist.Cache do
  @moduledoc """
  Owner process for the token-allowlist ETS table (W5 #1873).

  Deliberately does no database work: reads/writes happen inline in the
  requesting process (`MatomeApi.Auth.TokenAllowlist`), which keeps DB
  lookups inside the caller's Ecto sandbox ownership in tests and keeps this
  process's mailbox limited to PubSub invalidations.

  The table is `:public` so callers write entries directly; if this process
  crashes, the table (and every cached entry) dies with it — the allowlist
  then degrades to per-request DB lookups, never to a bypass.

  Subscribes to `TokenAllowlist.topic()` and deletes entries named by
  `{:token_allowlist_invalidate, jti}` broadcasts, which is how a revoke on
  one node busts the cache on all others.
  """

  use GenServer

  alias MatomeApi.Auth.TokenAllowlist

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    table =
      :ets.new(TokenAllowlist.table(), [
        :named_table,
        :set,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])

    :ok = Phoenix.PubSub.subscribe(MatomeApi.PubSub, TokenAllowlist.topic())
    {:ok, %{table: table}}
  end

  @impl GenServer
  def handle_info({:token_allowlist_invalidate, jti}, state) do
    :ets.delete(state.table, jti)
    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}
end
