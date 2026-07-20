defmodule MatomeApi.Repo.Migrations.CreateDevices do
  use Ecto.Migration

  # W4 p2-core-backoffice (#1872): device registry backing the sessions view
  # (W6) and revocation (W5). Purely additive — nothing reads this table yet.
  #
  # `client_id` is the device correlation key: a stable identifier the client
  # generates once and sends on every login (`device.id` in the login body).
  # It is unique PER USER, not globally — two accounts used from the same
  # physical device legitimately produce two rows, so the client identifier
  # cannot be the primary key. Rows created for clients that send no
  # identifier have `client_id` NULL and are correlated by user agent
  # instead (Postgres unique indexes treat NULLs as distinct, so multiple
  # NULL-client rows per user are allowed by design).
  def change do
    create table(:devices) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :client_id, :uuid
      add :platform, :string
      add :display_name, :string
      add :user_agent, :text
      add :first_seen_at, :utc_datetime, null: false
      add :last_seen_at, :utc_datetime, null: false
      add :device_key_enrolled, :boolean, null: false, default: false
      add :revoked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:devices, [:user_id])
    create unique_index(:devices, [:user_id, :client_id])
  end
end
