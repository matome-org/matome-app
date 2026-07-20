defmodule MatomeApi.Repo.Migrations.AddMatomesArchivedAt do
  use Ecto.Migration

  # Soft-delete (archive) for matomes (W3, task #1409). Nullable `archived_at`:
  # NULL ⟺ active; a timestamp ⟺ archived. Default list/read queries exclude
  # archived rows (`WHERE archived_at IS NULL`). Additive + nullable, so the
  # down-migration is a clean column drop with no data reshape.
  def change do
    alter table(:matomes) do
      add :archived_at, :utc_datetime
    end

    create index(:matomes, [:owner_id, :archived_at])
  end
end
