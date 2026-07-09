defmodule MatomeApi.Admin.TotpSecret do
  @moduledoc """
  The per-user admin TOTP factor (W3 #1871).

  `secret_ciphertext` is the RFC-6238 shared secret AFTER
  `MatomeApi.Admin.SecretVault` encryption — plaintext never reaches the DB.
  `confirmed_at` distinguishes an in-progress enrollment from an active
  factor; `last_used_timestep` is the replay high-water mark.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "totp_secrets" do
    belongs_to :user, MatomeApi.Auth.User
    field :secret_ciphertext, :binary, redact: true
    field :confirmed_at, :utc_datetime
    field :last_used_timestep, :integer

    timestamps(type: :utc_datetime)
  end

  def changeset(totp_secret, attrs) do
    totp_secret
    |> cast(attrs, [:user_id, :secret_ciphertext, :confirmed_at, :last_used_timestep])
    |> validate_required([:user_id, :secret_ciphertext])
    |> unique_constraint(:user_id)
  end
end
