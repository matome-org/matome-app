defmodule MatomeApi.SystemConfig.Reconciler do
  @moduledoc "Reapplies persisted desired Oban state whenever this Core node starts."

  use GenServer

  require Logger

  alias MatomeApi.SystemConfig
  alias MatomeApi.SystemConfig.{ObanQueueAdapter, QueueAdapter}

  def start_link(opts \\ []) do
    if Application.fetch_env!(:matome_api, Oban)[:queues] == false do
      :ignore
    else
      GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
    end
  end

  def reconcile_async do
    if Process.whereis(__MODULE__), do: GenServer.cast(__MODULE__, :reconcile)
    :ok
  end

  def reconcile_once(adapter \\ ObanQueueAdapter) do
    config = SystemConfig.get!()
    desired = queue_policy(config.document)

    with :ok <- QueueAdapter.apply(adapter, desired),
         {:ok, applied} <- SystemConfig.mark_applied(config.document["revision"]) do
      {:ok, applied}
    end
  rescue
    error -> {:error, error}
  end

  @impl true
  def init(opts) do
    state = %{adapter: Keyword.get(opts, :adapter, ObanQueueAdapter), timer: nil}
    {:ok, state, {:continue, :reconcile}}
  end

  @impl true
  def handle_continue(:reconcile, state), do: {:noreply, reconcile_and_schedule(state)}

  @impl true
  def handle_cast(:reconcile, state), do: {:noreply, reconcile_and_schedule(state)}

  @impl true
  def handle_info(:reconcile, state), do: {:noreply, reconcile_and_schedule(state)}

  defp reconcile_and_schedule(state) do
    if state.timer, do: Process.cancel_timer(state.timer)

    case reconcile_once(state.adapter) do
      {:ok, _config} ->
        :ok

      {:error, reason} ->
        Logger.warning("system policy reconciliation deferred: #{inspect(reason)}")
    end

    interval = reconcile_interval()

    %{state | timer: Process.send_after(self(), :reconcile, interval)}
  end

  defp reconcile_interval do
    SystemConfig.desired()["queue"]["snapshot_interval_seconds"]
    |> :timer.seconds()
  rescue
    _error -> :timer.seconds(60)
  end

  defp queue_policy(document) do
    document["desired"]["queue"]
    |> Map.take(["paused", "max_concurrency"])
  end
end
