defmodule MatomeApi.Repo.Migrations.CreateAdminLoginOtps do
  use Ecto.Migration

  def change do
    create table(:admin_login_otps) do
      add :email, :string, null: false
      add :code_hash, :binary, null: false
      add :expires_at, :utc_datetime_usec, null: false
      add :consumed_at, :utc_datetime_usec
      add :remote_ip, :string

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:admin_login_otps, [:email])
    create index(:admin_login_otps, [:expires_at])
  end
end
