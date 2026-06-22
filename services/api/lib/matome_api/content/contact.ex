defmodule MatomeApi.Content.Contact do
  use Ecto.Schema
  import Ecto.Changeset

  alias MatomeApi.Auth.User
  alias MatomeApi.Content.MatomeContact

  # Bound every user-controlled string field (#1462, Olivier HIGH AC).
  @max_email 254
  @max_phone 32
  @max_company 200
  @max_title 200

  # Conservative single-line email shape; full RFC 5322 is intentionally not
  # attempted. Rejects whitespace, multiple @, and obviously malformed input.
  @email_format ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/

  # Phone: digits with optional leading + and common separators. Validated
  # against the normalized value (separators stripped) so it must contain
  # 7..15 digits (E.164 upper bound), optional leading +.
  @phone_normalized_format ~r/^\+?\d{7,15}$/

  schema "contacts" do
    field :display_name, :string
    field :email, :string
    field :phone, :string
    field :company, :string
    field :title, :string
    field :metadata, :map, default: %{}

    belongs_to :owner, User
    belongs_to :linked_user, User
    has_many :matome_contacts, MatomeContact

    timestamps(type: :utc_datetime)
  end

  def changeset(contact, attrs) do
    contact
    |> cast(attrs, [:display_name, :email, :phone, :company, :title, :metadata, :linked_user_id])
    |> validate_required([:display_name])
    |> validate_length(:display_name, max: 255)
    |> normalize_email()
    |> validate_length(:email, max: @max_email)
    |> validate_format(:email, @email_format, message: "is not a valid email")
    |> normalize_phone()
    |> validate_length(:company, max: @max_company)
    |> validate_length(:title, max: @max_title)
    |> foreign_key_constraint(:linked_user_id)
  end

  # Lowercase + trim email before validation so storage/lookups are canonical.
  defp normalize_email(changeset) do
    update_change(changeset, :email, fn
      nil -> nil
      value -> value |> String.trim() |> String.downcase()
    end)
  end

  # Strip common separators, then validate the digit-only shape and length.
  # We store the normalized (separator-free) value.
  defp normalize_phone(changeset) do
    case get_change(changeset, :phone) do
      nil ->
        changeset

      value ->
        normalized = String.replace(value, ~r/[\s().\-]/, "")

        changeset
        |> put_change(:phone, normalized)
        |> validate_length(:phone, max: @max_phone)
        |> validate_format(:phone, @phone_normalized_format, message: "is not a valid phone number")
    end
  end
end
