defmodule MatomeApi.Content.Contact do
  use Ecto.Schema
  import Ecto.Changeset

  alias MatomeApi.Auth.User
  alias MatomeApi.Content.MatomeContact

  schema "contacts" do
    field :display_name, :string
    field :metadata, :map, default: %{}

    belongs_to :owner, User
    belongs_to :linked_user, User
    has_many :matome_contacts, MatomeContact

    timestamps(type: :utc_datetime)
  end

  def changeset(contact, attrs) do
    contact
    |> cast(attrs, [:display_name, :metadata, :linked_user_id])
    |> validate_required([:display_name])
    |> validate_length(:display_name, max: 255)
    |> foreign_key_constraint(:linked_user_id)
  end
end
