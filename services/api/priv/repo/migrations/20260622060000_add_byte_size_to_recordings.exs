defmodule MatomeApi.Repo.Migrations.AddByteSizeToRecordings do
  use Ecto.Migration

  # The uploaded media's size in BYTES, captured client-side at upload
  # (`file.length()`) and declared in the create request as `content_length`
  # (already SigV4-signed for the presigned PUT). Persisted here so the Files
  # view can render a real human size ("2.4 MB") instead of a dash.
  #
  # `:bigint` because a 4-byte int caps at ~2.1 GB — a recording/import can
  # exceed that. NULLABLE: legacy rows (and any row created before the client
  # declares a size) carry NULL, which the UI renders as "—".
  def change do
    alter table(:recordings) do
      add :byte_size, :bigint
    end
  end
end
