defmodule MatomeApi.Repo.Migrations.CreateRecordingContacts do
  use Ecto.Migration

  # Direct file↔contact join (#1472), mirroring `matome_contacts` (the
  # file↔contact relation was matome-mediated only — DR-003). Explicit up/down
  # so the rollback is exercised by the migration test; both endpoints cascade
  # on delete so removing a recording or contact cleans up its links.

  def up do
    create table(:recording_contacts) do
      add :recording_id, references(:recordings, on_delete: :delete_all), null: false
      add :contact_id, references(:contacts, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:recording_contacts, [:recording_id, :contact_id])
  end

  def down do
    drop table(:recording_contacts)
  end
end
