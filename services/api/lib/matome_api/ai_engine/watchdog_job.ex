defmodule MatomeApi.AIEngine.WatchdogJob do
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [
      keys: [:processing_run_id],
      period: :infinity,
      states: [:available, :scheduled, :executing, :retryable, :suspended, :completed]
    ]

  alias MatomeApi.Content

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "item_id" => item_id,
          "processing_run_id" => processing_run_id,
          "source_revision" => source_revision
        }
      }) do
    case Content.timeout_item_processing(item_id, processing_run_id, source_revision) do
      {:ok, {:not_due, seconds}} -> {:snooze, seconds}
      {:ok, _terminal_or_stale} -> :ok
      {:error, :not_found} -> {:discard, :missing_item}
      {:error, reason} -> {:error, reason}
    end
  end

  def perform(%Oban.Job{}), do: {:discard, :invalid_args}
end
