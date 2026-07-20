defmodule MatomeApi.SystemConfig.ObanQueueAdapter do
  @moduledoc false

  @behaviour MatomeApi.SystemConfig.QueueAdapter

  @queue :ai

  @impl true
  def apply(%{"paused" => paused, "max_concurrency" => concurrency}) do
    with :ok <- Oban.scale_queue(queue: @queue, limit: concurrency, local_only: true),
         :ok <- set_paused(paused) do
      :ok
    end
  rescue
    error -> {:error, error}
  end

  @impl true
  def status do
    case Oban.check_queue(queue: @queue) do
      nil -> {:error, :queue_unavailable}
      queue -> {:ok, %{"paused" => queue.paused, "max_concurrency" => queue.limit}}
    end
  rescue
    error -> {:error, error}
  end

  defp set_paused(true), do: Oban.pause_queue(queue: @queue, local_only: true)
  defp set_paused(false), do: Oban.resume_queue(queue: @queue, local_only: true)
end
