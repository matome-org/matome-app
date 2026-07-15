defmodule MatomeApi.Repo.Migrations.ReplaceRecordingsWithItems do
  use Ecto.Migration

  def up do
    drop_if_exists table(:recording_contacts)
    drop_if_exists table(:recordings)

    create unique_index(:matomes, [:id, :owner_id], name: :matomes_id_owner_id_index)
    create unique_index(:workspaces, [:id, :owner_id], name: :workspaces_id_owner_id_index)

    create table(:file_blobs) do
      add :storage_key, :text, null: false
      add :filename, :text
      add :content_type, :string
      add :byte_size, :bigint, null: false
      add :checksum_sha256, :string
      add :media_type, :string, null: false
      add :duration, :integer
      add :upload_state, :string, null: false, default: "pending"
      add :upload_generation, :bigint, null: false, default: 1
      add :uploaded_at, :utc_datetime
      add :multipart_context, :map

      timestamps(type: :utc_datetime)
    end

    create constraint(:file_blobs, :file_blobs_media_type_check,
             check: "media_type IN ('audio', 'image', 'document', 'video')"
           )

    create constraint(:file_blobs, :file_blobs_byte_size_check, check: "byte_size >= 0")

    create constraint(:file_blobs, :file_blobs_filename_check,
             check: "filename IS NULL OR char_length(btrim(filename)) BETWEEN 1 AND 1024"
           )

    create constraint(:file_blobs, :file_blobs_content_type_check,
             check: "content_type IS NULL OR char_length(btrim(content_type)) BETWEEN 1 AND 255"
           )

    create constraint(:file_blobs, :file_blobs_checksum_sha256_check,
             check: "checksum_sha256 IS NULL OR checksum_sha256 ~ '^[0-9a-f]{64}$'"
           )

    create constraint(:file_blobs, :file_blobs_upload_state_check,
             check: "upload_state IN ('pending', 'uploading', 'uploaded', 'failed', 'aborted')"
           )

    create constraint(:file_blobs, :file_blobs_upload_generation_check,
             check: "upload_generation > 0"
           )

    create constraint(:file_blobs, :file_blobs_uploaded_at_check,
             check: "(upload_state = 'uploaded') = (uploaded_at IS NOT NULL)"
           )

    create constraint(:file_blobs, :file_blobs_multipart_context_check,
             check: """
             multipart_context IS NULL
             OR (
               upload_state IN ('pending', 'uploading')
               AND jsonb_typeof(multipart_context) = 'object'
               AND octet_length(multipart_context::text) <= 262144
             )
             """
           )

    create table(:text_contents) do
      add :body, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create constraint(:text_contents, :text_contents_body_check,
             check: "char_length(body) BETWEEN 1 AND 200000"
           )

    create table(:items) do
      add :owner_id, references(:users, on_delete: :delete_all), null: false
      add :client_id, :text
      add :client_fingerprint, :string
      add :workspace_id, :bigint
      add :matome_id, :bigint
      add :position, :integer
      add :item_type, :string, null: false
      add :title, :string, null: false, default: "Untitled"
      add :notes, :text
      add :metadata, :map, null: false, default: %{}
      add :processing_state, :string, null: false, default: "not_requested"
      add :processing_run_id, :uuid
      add :source_revision, :bigint, null: false, default: 1
      add :processing_config_revision, :bigint
      add :processing_outputs, :map, null: false, default: %{}
      add :processing_error, :map
      add :file_blob_id, references(:file_blobs, on_delete: :restrict)
      add :text_content_id, references(:text_contents, on_delete: :restrict)

      timestamps(type: :utc_datetime)
    end

    create index(:items, [:owner_id])
    create index(:items, [:owner_id, :matome_id])
    create index(:items, [:owner_id, :workspace_id])

    create unique_index(:items, [:owner_id, :client_id],
             where: "client_id IS NOT NULL",
             name: :items_owner_id_client_id_index
           )

    create unique_index(:items, [:matome_id, :position],
             where: "matome_id IS NOT NULL AND position IS NOT NULL",
             name: :items_matome_id_position_index
           )

    create unique_index(:items, [:file_blob_id], where: "file_blob_id IS NOT NULL")
    create unique_index(:items, [:text_content_id], where: "text_content_id IS NOT NULL")

    execute """
    ALTER TABLE items
    ADD CONSTRAINT items_owner_matome_fkey
    FOREIGN KEY (matome_id, owner_id)
    REFERENCES matomes(id, owner_id)
    ON DELETE SET NULL (matome_id)
    """

    execute """
    ALTER TABLE items
    ADD CONSTRAINT items_owner_workspace_fkey
    FOREIGN KEY (workspace_id, owner_id)
    REFERENCES workspaces(id, owner_id)
    ON DELETE SET NULL (workspace_id)
    """

    create constraint(:items, :items_item_type_check, check: "item_type IN ('file', 'text')")

    create constraint(:items, :items_payload_exclusive_arc_check,
             check: """
             (item_type = 'file' AND file_blob_id IS NOT NULL AND text_content_id IS NULL)
             OR
             (item_type = 'text' AND text_content_id IS NOT NULL AND file_blob_id IS NULL)
             """
           )

    create constraint(:items, :items_position_check,
             check: """
             (matome_id IS NULL AND position IS NULL)
             OR
             (matome_id IS NOT NULL AND position >= 0)
             """
           )

    create constraint(:items, :items_client_identity_check,
             check: """
             (client_id IS NULL AND client_fingerprint IS NULL)
             OR
             (
               client_id IS NOT NULL
               AND char_length(client_id) BETWEEN 1 AND 255
               AND client_fingerprint IS NOT NULL
             )
             """
           )

    create constraint(:items, :items_processing_state_check,
             check:
               "processing_state IN ('not_requested', 'queued', 'processing', 'succeeded', 'failed')"
           )

    create constraint(:items, :items_processing_run_check,
             check: """
             (processing_state = 'not_requested' AND processing_run_id IS NULL)
             OR
             (processing_state != 'not_requested' AND processing_run_id IS NOT NULL)
             """
           )

    create constraint(:items, :items_processing_revision_check,
             check:
               "source_revision > 0 AND (processing_config_revision IS NULL OR processing_config_revision >= 0)"
           )

    create constraint(:items, :items_metadata_check, check: "jsonb_typeof(metadata) = 'object'")

    create constraint(:items, :items_processing_outputs_check,
             check:
               "jsonb_typeof(processing_outputs) = 'object' AND octet_length(processing_outputs::text) <= 4194304"
           )

    create constraint(:items, :items_processing_error_check,
             check: """
             processing_error IS NULL
             OR (
               processing_state = 'failed'
               AND jsonb_typeof(processing_error) = 'object'
               AND octet_length(processing_error::text) <= 16384
             )
             """
           )
  end

  def down do
    drop_if_exists table(:items)
    drop_if_exists table(:text_contents)
    drop_if_exists table(:file_blobs)
    drop_if_exists index(:matomes, [:id, :owner_id], name: :matomes_id_owner_id_index)
    drop_if_exists index(:workspaces, [:id, :owner_id], name: :workspaces_id_owner_id_index)

    create table(:recordings) do
      add :owner_id, references(:users, on_delete: :delete_all), null: false
      add :workspace_id, references(:workspaces, on_delete: :nilify_all)
      add :matome_id, references(:matomes, on_delete: :nilify_all)
      add :title, :string, null: false
      add :summary, :text
      add :transcript, :text
      add :notes, :text
      add :media_type, :string
      add :storage_key, :text
      add :status, :string, null: false, default: "pending"
      add :error_reason, :text
      add :duration, :integer
      add :byte_size, :bigint
      add :badge, :string

      timestamps(type: :utc_datetime)
    end

    create index(:recordings, [:owner_id])
    create index(:recordings, [:owner_id, :workspace_id])
    create index(:recordings, [:owner_id, :status])
    create index(:recordings, [:owner_id, :matome_id])

    create constraint(:recordings, :recordings_status_check,
             check: "status IN ('pending', 'processing', 'done', 'failed')"
           )

    create table(:recording_contacts) do
      add :recording_id, references(:recordings, on_delete: :delete_all), null: false
      add :contact_id, references(:contacts, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:recording_contacts, [:recording_id, :contact_id])
  end
end
