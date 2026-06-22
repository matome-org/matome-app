defmodule MatomeApi.Content.RecordingContact do
  use Ecto.Schema
  import Ecto.Changeset

  alias MatomeApi.Content.{Contact, Recording}

  # Direct file↔contact edge (#1472), mirroring `MatomeContact`. The
  # owner-scoping that actually protects this edge lives in the context
  # (`Content.link_contact_to_recording`/`unlink_contact_from_recording`),
  # which verifies BOTH the recording AND the contact belong to the actor
  # before inserting — the changeset only enforces shape + the UNIQUE pair.
  schema "recording_contacts" do
    belongs_to :recording, Recording
    belongs_to :contact, Contact

    timestamps(type: :utc_datetime)
  end

  def changeset(recording_contact, attrs) do
    recording_contact
    |> cast(attrs, [:recording_id, :contact_id])
    |> validate_required([:recording_id, :contact_id])
    |> foreign_key_constraint(:recording_id)
    |> foreign_key_constraint(:contact_id)
    |> unique_constraint([:recording_id, :contact_id])
  end
end
