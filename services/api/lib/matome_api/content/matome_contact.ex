defmodule MatomeApi.Content.MatomeContact do
  use Ecto.Schema
  import Ecto.Changeset

  alias MatomeApi.Content.{Contact, Matome}

  schema "matome_contacts" do
    field :role, :string, default: "attendee"

    belongs_to :matome, Matome
    belongs_to :contact, Contact

    timestamps(type: :utc_datetime)
  end

  def changeset(matome_contact, attrs) do
    matome_contact
    |> cast(attrs, [:matome_id, :contact_id, :role])
    |> validate_required([:matome_id, :contact_id, :role])
    |> foreign_key_constraint(:matome_id)
    |> foreign_key_constraint(:contact_id)
    |> unique_constraint([:matome_id, :contact_id])
  end
end
