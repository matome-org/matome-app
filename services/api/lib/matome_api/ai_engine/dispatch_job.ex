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
  def perform(%Oban.Job{args: %{"item_id" => item_id, "file_blob_id" => file_blob_id}}) do
    with {:ok, payload} <- Content.ai_dispatch_payload(item_id, file_blob_id) do
      AIEngine.dispatch(payload)
      |> case do
        {:ok, _body} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def perform(%Oban.Job{}), do: {:discard, :invalid_args}
end
