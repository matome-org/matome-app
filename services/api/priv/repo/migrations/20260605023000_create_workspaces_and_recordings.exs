defmodule MatomeApi.Repo.Migrations.CreateWorkspacesAndRecordings do
  use Ecto.Migration

  def change do
    create table(:workspaces) do
      add :owner_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :description, :text

      timestamps(type: :utc_datetime)
    end

    create index(:workspaces, [:owner_id])
    create unique_index(:workspaces, [:owner_id, :name])

    create table(:recordings) do
      add :owner_id, references(:users, on_delete: :delete_all), null: false
      add :workspace_id, references(:workspaces, on_delete: :nilify_all)
      add :title, :string, null: false
      add :summary, :text
      add :transcript, :text
      add :media_type, :string
      add :storage_key, :text
      add :status, :string, null: false, default: "pending"
      add :error_reason, :text
      add :duration, :integer
      add :badge, :string

      timestamps(type: :utc_datetime)
    end

    create index(:recordings, [:owner_id])
    create index(:recordings, [:owner_id, :workspace_id])
    create index(:recordings, [:owner_id, :status])

    create constraint(:recordings, :recordings_status_check,
             check: "status IN ('pending', 'processing', 'done', 'failed')"
           )
  end
end
