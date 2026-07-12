defmodule MatomeApi.Content.SpaceMember do
  use Ecto.Schema
  import Ecto.Changeset

  alias MatomeApi.Auth.User
  alias MatomeApi.Content.Workspace

  @roles ~w(owner admin member viewer)

  schema "space_members" do
    field :role, :string, default: "member"
    field :granted_at, :utc_datetime
    field :revoked_at, :utc_datetime

    belongs_to :workspace, Workspace
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  def changeset(member, attrs) do
    member
    |> cast(attrs, [:workspace_id, :user_id, :role, :granted_at, :revoked_at])
    |> validate_required([:workspace_id, :user_id, :role, :granted_at])
    |> validate_inclusion(:role, @roles)
    |> unique_constraint([:workspace_id, :user_id])
    |> foreign_key_constraint(:workspace_id)
    |> foreign_key_constraint(:user_id)
  end
end
