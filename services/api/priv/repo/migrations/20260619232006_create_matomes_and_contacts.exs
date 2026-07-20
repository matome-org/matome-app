defmodule MatomeApi.Repo.Migrations.CreateMatomesAndContacts do
  use Ecto.Migration

  def change do
    create table(:matomes) do
      add :owner_id, references(:users, on_delete: :delete_all), null: false
      add :client_id, :text
      add :client_fingerprint, :string
      add :workspace_id, references(:workspaces, on_delete: :nilify_all)
      add :title, :string, null: false
      add :happened_at, :utc_datetime
      add :description, :text
      add :aggregated_summary, :text

      timestamps(type: :utc_datetime)
    end

    create index(:matomes, [:owner_id])
    create index(:matomes, [:owner_id, :workspace_id])

    create unique_index(:matomes, [:owner_id, :client_id],
             where: "client_id IS NOT NULL",
             name: :matomes_owner_id_client_id_index
           )

    create constraint(:matomes, :matomes_client_identity_check,
             check: """
             (client_id IS NULL AND client_fingerprint IS NULL)
             OR
             (
               client_id IS NOT NULL
               AND char_length(client_id) BETWEEN 1 AND 255
               AND client_id ~ '\\S'
               AND client_fingerprint IS NOT NULL
               AND client_fingerprint ~ '^[0-9a-f]{64}$'
             )
             """
           )

    alter table(:recordings) do
      add :matome_id, references(:matomes, on_delete: :nilify_all)
    end

    create index(:recordings, [:owner_id, :matome_id])

    create table(:contacts) do
      add :owner_id, references(:users, on_delete: :delete_all), null: false
      add :display_name, :string, null: false
      add :metadata, :map, null: false, default: %{}
      add :linked_user_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:contacts, [:owner_id])

    create table(:matome_contacts) do
      add :matome_id, references(:matomes, on_delete: :delete_all), null: false
      add :contact_id, references(:contacts, on_delete: :delete_all), null: false
      add :role, :string, null: false, default: "attendee"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:matome_contacts, [:matome_id, :contact_id])
  end
end
