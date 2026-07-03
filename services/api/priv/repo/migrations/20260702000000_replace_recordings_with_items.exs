defmodule MatomeApi.Repo.Migrations.ReplaceRecordingsWithItems do
  use Ecto.Migration

  def up do
    drop_if_exists table(:recording_contacts)
    drop_if_exists table(:recordings)

    create table(:file_blobs) do
      add :storage_key, :text, null: false
      add :byte_size, :bigint, null: false
      add :media_type, :string, null: false
      add :duration, :integer
      add :transcript, :text
      add :summary, :text

      timestamps(type: :utc_datetime)
    end

    create constraint(:file_blobs, :file_blobs_media_type_check,
             check: "media_type IN ('audio', 'image', 'document', 'video')"
           )

    create table(:text_contents) do
      add :body, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create table(:items) do
      add :matome_id, references(:matomes, on_delete: :delete_all), null: false
      add :position, :integer, null: false
      add :item_type, :string, null: false
      add :metadata, :map, null: false, default: %{}
      add :file_blob_id, references(:file_blobs, on_delete: :restrict)
      add :text_content_id, references(:text_contents, on_delete: :restrict)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:items, [:matome_id, :position])
    create unique_index(:items, [:file_blob_id], where: "file_blob_id IS NOT NULL")
    create unique_index(:items, [:text_content_id], where: "text_content_id IS NOT NULL")

    create constraint(:items, :items_item_type_check, check: "item_type IN ('file', 'text')")

    create constraint(:items, :items_payload_exclusive_arc_check,
             check: """
             (item_type = 'file' AND file_blob_id IS NOT NULL AND text_content_id IS NULL)
             OR
             (item_type = 'text' AND text_content_id IS NOT NULL AND file_blob_id IS NULL)
             """
           )
  end

  def down do
    drop_if_exists table(:items)
    drop_if_exists table(:text_contents)
    drop_if_exists table(:file_blobs)

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
