defmodule MatomeApi.Content.Workspace do
  use Ecto.Schema
  import Ecto.Changeset

  alias MatomeApi.Auth.User
  alias MatomeApi.Content.{Matome, Recording}

  schema "workspaces" do
    field :name, :string
    field :description, :string

    belongs_to :owner, User
    has_many :recordings, Recording
    has_many :matomes, Matome

    timestamps(type: :utc_datetime)
  end

  def changeset(workspace, attrs) do
    workspace
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
    |> validate_length(:name, max: 255)
    |> unique_constraint([:owner_id, :name])
  end
end
