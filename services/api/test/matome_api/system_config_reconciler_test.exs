defmodule MatomeApi.SystemConfigReconcilerTest do
  use MatomeApi.DataCase, async: false

  alias MatomeApi.SystemConfig
  alias MatomeApi.SystemConfig.Reconciler

  defmodule QueueAdapter do
    def apply(policy, agent) do
      Agent.update(agent, &Map.merge(&1, policy))
      :ok
    end

    def status(agent), do: {:ok, Agent.get(agent, & &1)}
  end

  test "reports mismatch, reapplies desired Oban state, and marks the same revision effective" do
    {:ok, queue} = Agent.start_link(fn -> %{"paused" => true, "max_concurrency" => 1} end)
    on_exit(fn -> if Process.alive?(queue), do: Agent.stop(queue) end)

    assert %{
             desired: %{"paused" => false, "max_concurrency" => 2},
             effective: %{"paused" => true, "max_concurrency" => 1},
             mismatch: true,
             restart_required: false
           } = SystemConfig.status({QueueAdapter, queue}).queue

    assert {:ok, applied} = Reconciler.reconcile_once({QueueAdapter, queue})
    revision = applied.document["revision"]
    assert applied.document["applied"]["core_revision"] == revision
    assert is_binary(applied.document["applied"]["core_applied_at"])

    assert %{
             effective: %{"paused" => false, "max_concurrency" => 2},
             mismatch: false,
             restart_required: false
           } = SystemConfig.status({QueueAdapter, queue}).queue

    # A node/producer restart loses runtime state; the same persisted desired
    # revision is deliberately applied again without creating a config revision.
    Agent.update(queue, fn _ -> %{"paused" => true, "max_concurrency" => 1} end)
    assert {:ok, reapplied} = Reconciler.reconcile_once({QueueAdapter, queue})
    assert reapplied.document["revision"] == revision
    assert Agent.get(queue, & &1) == %{"paused" => false, "max_concurrency" => 2}
  end

  test "an unavailable producer is visible as mismatch requiring restart" do
    adapter = {__MODULE__.UnavailableQueue, nil}

    assert %{effective: nil, mismatch: true, restart_required: true} =
             SystemConfig.status(adapter).queue
  end

  defmodule UnavailableQueue do
    def apply(_policy, _arg), do: {:error, :queue_unavailable}
    def status(_arg), do: {:error, :queue_unavailable}
  end
end
