defmodule MatomeApi.Repo.Migrations.AddDocumentOpenPolicy do
  use Ecto.Migration

  def change do
    alter table(:file_blobs) do
      add :original_extension, :string
      add :open_policy, :string, null: false, default: "download_only"
    end

    create constraint(:file_blobs, :file_blobs_original_extension_check,
             check:
               "original_extension IS NULL OR original_extension ~ '^[a-z0-9][a-z0-9+_-]{0,31}$'"
           )

    create constraint(:file_blobs, :file_blobs_open_policy_check,
             check:
               "open_policy IN ('external', 'system_app', 'attachment_only', 'download_only', 'blocked')"
           )

    create constraint(:file_blobs, :file_blobs_document_metadata_check,
             check:
               "media_type <> 'document' OR (filename IS NOT NULL AND length(filename) > 0 AND content_type IS NOT NULL AND length(content_type) > 0)"
           )
  end
end
