defmodule MatomeApi.RateLimiter.TableHeir do
  @moduledoc """
  Dedicated, minimal heir for `MatomeApi.RateLimiter`'s ETS table
  (okt-audit AUDIT-CORE, task #1865).

  When an ETS table's owner process dies, the runtime hands ownership to
  the table's `heir:` process instead of destroying the table — but only
  if that heir is alive and only if it does something sane with the
  `:"ETS-TRANSFER"` message it receives. Pointing `heir:` at an arbitrary
  long-lived process (e.g. the top-level application supervisor) "works"
  in that the table survives, but that process doesn't expect the
  message and logs an "unexpected message" error every time.

  This process exists solely to receive that message and do nothing with
  it. Since the table is `:public`, every other process (including a
  freshly-restarted `MatomeApi.RateLimiter`) can keep reading/writing it
  regardless of which process currently "owns" it in the ETS sense — no
  further hand-back is needed.
  """
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts), do: {:ok, nil}

  @impl true
  def handle_info({:"ETS-TRANSFER", _table, _from_pid, _heir_data}, state) do
    {:noreply, state}
  end
end
