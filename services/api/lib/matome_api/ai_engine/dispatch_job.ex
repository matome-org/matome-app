defmodule MatomeApi.AIEngine.DispatchJob do
  use Oban.Worker, queue: :ai, max_attempts: 3

  alias MatomeApi.{AIEngine, Content, Repo}
  alias MatomeApi.Content.Recording

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"recording_id" => recording_id}, attempt: attempt}) do
    case Repo.get(Recording, recording_id) do
      nil ->
        :discard

      %Recording{status: status} when status in [:done, :failed] ->
        :ok

      %Recording{} = recording ->
        with {:ok, processing} <- Content.mark_recording_processing(recording),
             {:ok, _response} <- AIEngine.dispatch(processing, attempt) do
          :ok
        else
          {:error, reason} -> {:error, reason}
        end
    end
  end
end
