defmodule MatomeApi.Repo.Migrations.CreateAuthUsersAndRefreshTokens do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", "DROP EXTENSION IF EXISTS citext"

    create table(:users) do
      add :email, :citext, null: false
      add :password_hash, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])

    create table(:refresh_tokens) do
      add :token, :text, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:refresh_tokens, [:token])
    create index(:refresh_tokens, [:user_id])
  end
end
