defmodule MatomeApi.Admin.LoginOtp do
  @moduledoc """
  One-shot email OTP for /admin login. Only the hash is persisted.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "admin_login_otps" do
    field :email, :string
    field :code_hash, :binary
    field :expires_at, :utc_datetime_usec
    field :consumed_at, :utc_datetime_usec
    field :remote_ip, :string

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(otp, attrs) do
    otp
    |> cast(attrs, [:email, :code_hash, :expires_at, :consumed_at, :remote_ip])
    |> validate_required([:email, :code_hash, :expires_at])
    |> update_change(:email, &String.downcase/1)
  end
end
