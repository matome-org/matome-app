defmodule MatomeApi.Repo.Migrations.AddNotesToRecordings do
  use Ecto.Migration

  def change do
    alter table(:recordings) do
      add :notes, :text
    end
  end
end
