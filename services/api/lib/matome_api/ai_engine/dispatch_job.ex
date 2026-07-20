defmodule MatomeApi.AIEngine.DispatchJob do
  # Transport retries retain one run id while a user retry creates another.
  # Uniqueness therefore follows the logical run rather than mutable item input.
  use Oban.Worker,
    queue: :ai,
    max_attempts: 3,
    unique: [
      keys: [:processing_run_id],
      period: :infinity,
      states: [:available, :scheduled, :executing, :retryable, :suspended, :completed]
    ]

  alias MatomeApi.AIEngine
  alias MatomeApi.AIEngine.Contract
  alias MatomeApi.Content

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "item_id" => item_id,
          "processing_run_id" => processing_run_id,
          "source_revision" => source_revision,
          "processing" => %{"job_timeout_seconds" => timeout_seconds}
        }
      }) do
    with {:ok, payload} <-
           Content.ai_dispatch_payload(item_id, processing_run_id, source_revision),
         {:ok, body} <- AIEngine.dispatch(payload, timeout_seconds),
         :ok <- Contract.validate_dispatch_ack(body, payload) do
      :ok
    else
      {:discard, reason} -> {:discard, reason}
      {:error, reason} -> {:error, reason}
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
