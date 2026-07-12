defmodule MatomeApi.Repo.Migrations.CreateSpaceKeyWraps do
  @moduledoc """
  W9 / ADR-0003 — opaque space-KEK wraps (wrapper_type 0x05).
  Core stores ciphertext only; never inspects keys.
  """
  use Ecto.Migration

  def change do
    create table(:space_key_wraps) do
      add :workspace_id, references(:workspaces, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :wrapper_blob, :text, null: false
      add :ephemeral_pubkey, :text, null: false
      add :alg_id, :integer, null: false, default: 1
      add :created_by_id, references(:users, on_delete: :nilify_all)
      add :revoked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:space_key_wraps, [:workspace_id])
    create index(:space_key_wraps, [:user_id])
    create unique_index(:space_key_wraps, [:workspace_id, :user_id])

    create constraint(:space_key_wraps, :space_key_wraps_alg_id_check, check: "alg_id = 1")
  end
end
