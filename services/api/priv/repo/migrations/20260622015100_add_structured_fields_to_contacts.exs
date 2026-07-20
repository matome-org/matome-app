defmodule MatomeApi.Repo.Migrations.AddStructuredFieldsToContacts do
  use Ecto.Migration

  # Typed columns for structured contact fields (#1462). Chosen over a
  # free-form metadata blob so writes are validated/normalized at the schema
  # layer. All nullable — existing contacts have none of these set.
  def change do
    alter table(:contacts) do
      add :email, :string
      add :phone, :string
      add :company, :string
      add :title, :string
    end
  end
end
