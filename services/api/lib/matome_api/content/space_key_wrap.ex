defmodule MatomeApi.Content.SpaceKeyWrap do
  use Ecto.Schema
  import Ecto.Changeset

  alias MatomeApi.Auth.User
  alias MatomeApi.Content.Workspace

  schema "space_key_wraps" do
    field :wrapper_blob, :string
    field :ephemeral_pubkey, :string
    field :alg_id, :integer, default: 1
    field :revoked_at, :utc_datetime

    belongs_to :workspace, Workspace
    belongs_to :user, User
    belongs_to :created_by, User

    timestamps(type: :utc_datetime)
  end

  def changeset(wrap, attrs) do
    wrap
    |> cast(attrs, [
      :workspace_id,
      :user_id,
      :wrapper_blob,
      :ephemeral_pubkey,
      :alg_id,
      :created_by_id,
      :revoked_at
    ])
    |> validate_required([
      :workspace_id,
      :user_id,
      :wrapper_blob,
      :ephemeral_pubkey,
      :alg_id
    ])
    |> validate_number(:alg_id, equal_to: 1)
    |> validate_length(:wrapper_blob, min: 1, max: 512)
    |> validate_length(:ephemeral_pubkey, min: 1, max: 128)
    |> unique_constraint([:workspace_id, :user_id])
    |> foreign_key_constraint(:workspace_id)
    |> foreign_key_constraint(:user_id)
  end
end
