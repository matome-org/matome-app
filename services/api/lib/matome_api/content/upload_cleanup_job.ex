defmodule MatomeApi.Content.UploadCleanupJob do
  use Oban.Worker, queue: :default, max_attempts: 10

  alias MatomeApi.Content.UploadLifecycle

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"file_blob_id" => file_blob_id, "upload_generation" => generation}
      }) do
    UploadLifecycle.expire(file_blob_id, generation)
  end
end
