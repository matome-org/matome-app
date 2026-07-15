defmodule MatomeApi.AIEngine.DispatchJob do
  # `unique` makes POST /items/:id/process idempotent: repeated calls for the
  # same (item_id, file_blob_id) collapse onto the existing job instead of
  # enqueuing unbounded AI work. Scoped by the two arg keys over all live +
  # completed states so a re-request never double-dispatches.
  use Oban.Worker,
    queue: :ai,
    max_attempts: 3,
    unique: [
      keys: [:item_id, :file_blob_id],
      period: :infinity,
      states: [:available, :scheduled, :executing, :retryable, :suspended, :completed]
    ]

  alias MatomeApi.AIEngine
  alias MatomeApi.Content

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "item_id" => item_id,
          "file_blob_id" => file_blob_id,
          "processing" => %{"job_timeout_seconds" => timeout_seconds}
        }
      }) do
    with {:ok, payload} <- Content.ai_dispatch_payload(item_id, file_blob_id) do
      AIEngine.dispatch(payload, timeout_seconds)
      |> case do
        {:ok, _body} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def perform(%Oban.Job{}), do: {:discard, :invalid_args}

  @impl Oban.Worker
  def backoff(%Oban.Job{
        attempt: attempt,
        args: %{
          "retry" => %{
            "base_delay_seconds" => base_delay,
            "max_delay_seconds" => max_delay
          }
        }
      }) do
    cap = min(max_delay, trunc(base_delay * :math.pow(2, max(attempt - 1, 0))))
    :rand.uniform(cap + 1) - 1
  end
end
