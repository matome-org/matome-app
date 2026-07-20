defmodule MatomeApi.Repo.Migrations.CreateTotpSecrets do
  use Ecto.Migration

  @moduledoc """
  W3 #1871 (plan p2-core-backoffice §9.1) — storage for the mandatory admin
  TOTP factor.

  - `secret_ciphertext` holds the RFC-6238 shared secret encrypted at rest
    (AES-256-GCM via `MatomeApi.Admin.SecretVault`); the plaintext secret
    never touches the database.
  - `confirmed_at` gates enrollment: a secret only counts as an active MFA
    factor after the user has proven possession by verifying one code.
  - `last_used_timestep` is the replay guard: a code for a timestep <= this
    value is rejected even if otherwise valid (RFC 6238 §5.2 one-time use).
  """

  def change do
    create table(:totp_secrets) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :secret_ciphertext, :binary, null: false
      add :confirmed_at, :utc_datetime
      add :last_used_timestep, :bigint

      timestamps(type: :utc_datetime)
    end

    create unique_index(:totp_secrets, [:user_id])
  end
end
