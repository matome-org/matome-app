defmodule MatomeApi.Repo.Migrations.AddItemClientIdIdempotency do
  use Ecto.Migration

  def change do
    alter table(:items) do
      add :owner_id, references(:users, on_delete: :delete_all), null: false
      add :client_id, :text
      add :client_fingerprint, :string
    end

    create index(:items, [:owner_id])

    create unique_index(:items, [:owner_id, :client_id],
             where: "client_id IS NOT NULL",
             name: :items_owner_id_client_id_index
           )
  end
end
