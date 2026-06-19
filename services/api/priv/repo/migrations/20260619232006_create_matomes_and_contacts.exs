defmodule MatomeApi.Repo.Migrations.CreateMatomesAndContacts do
  use Ecto.Migration

  def change do
    create table(:matomes) do
      add :owner_id, references(:users, on_delete: :delete_all), null: false
      add :workspace_id, references(:workspaces, on_delete: :nilify_all)
      add :title, :string, null: false
      add :happened_at, :utc_datetime
      add :description, :text
      add :aggregated_summary, :text

      timestamps(type: :utc_datetime)
    end

    create index(:matomes, [:owner_id])
    create index(:matomes, [:owner_id, :workspace_id])

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
