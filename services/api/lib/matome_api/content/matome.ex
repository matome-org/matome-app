defmodule MatomeApi.Content.Matome do
  use Ecto.Schema
  import Ecto.Changeset

  alias MatomeApi.Auth.User
  alias MatomeApi.Content.{MatomeContact, Recording, Workspace}

  schema "matomes" do
    field :title, :string
    field :happened_at, :utc_datetime
    field :description, :string
    field :aggregated_summary, :string

    belongs_to :owner, User
    belongs_to :workspace, Workspace
    has_many :recordings, Recording
    has_many :matome_contacts, MatomeContact

    timestamps(type: :utc_datetime)
  end

  def changeset(matome, attrs) do
    matome
    |> cast(attrs, [
      :title,
      :happened_at,
      :description,
      :aggregated_summary,
      :workspace_id
    ])
    |> validate_required([:title])
    |> validate_length(:title, max: 255)
    |> foreign_key_constraint(:workspace_id)
  end
end
