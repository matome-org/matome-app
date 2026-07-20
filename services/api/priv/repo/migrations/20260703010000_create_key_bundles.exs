defmodule MatomeApi.Repo.Migrations.CreateKeyBundles do
  use Ecto.Migration

  def change do
    create table(:key_bundles) do
      add :user_id, references(:users, on_delete: :delete_all), null: false

      # All of the following are opaque, client-generated blobs (base64
      # ciphertext / random salts). The server never parses or derives
      # anything from them — see .docs/internal/at-rest-key-flow.md
      # Appendix A. Stored as :text, not decoded to :binary, so no
      # encoding step ever touches the bytes the client sent.
      add :wrapped_dek_pw, :text, null: false
      add :wrapped_dek_recovery, :text, null: false
      add :salt_enc, :text, null: false
      add :salt_rec, :text, null: false
      add :salt_auth, :text, null: false

      # Small versioned KDF profile descriptor (Appendix A.6) — jsonb.
      add :kdf_params, :map, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:key_bundles, [:user_id])
  end
end
