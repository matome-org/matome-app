defmodule MatomeApi.Content.Workspace do
  use Ecto.Schema
  import Ecto.Changeset

  alias MatomeApi.Auth.User
  alias MatomeApi.Content.{Matome, SpaceMember}

  @space_types ~w(personal shared org)
  @statuses ~w(active suspended archived deleted)

  schema "workspaces" do
    field :name, :string
    field :description, :string

    # #102 Axis A — sync. Core rows default cloud (false).
    field :is_local, :boolean, default: false
    # #102 Axis B — tenancy.
    field :space_type, :string, default: "personal"

    field :quota_bytes, :integer
    field :used_bytes, :integer, default: 0
    field :expires_at, :utc_datetime
    field :status, :string, default: "active"

    belongs_to :owner, User
    has_many :matomes, Matome
    has_many :space_members, SpaceMember

    timestamps(type: :utc_datetime)
  end

  def changeset(workspace, attrs) do
    workspace
    |> cast(attrs, [
      :name,
      :description,
      :is_local,
      :space_type,
      :quota_bytes,
      :expires_at,
      :status
    ])
    |> validate_required([:name])
    |> validate_length(:name, max: 255)
    |> validate_inclusion(:space_type, @space_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:quota_bytes, greater_than_or_equal_to: 0)
    |> validate_two_axis_invariants()
    |> unique_constraint([:owner_id, :name])
  end

  @doc "Admin-only fields (quota, expiry, lifecycle, axes)."
  def admin_changeset(workspace, attrs) do
    workspace
    |> cast(attrs, [
      :name,
      :description,
      :is_local,
      :space_type,
      :quota_bytes,
      :expires_at,
      :status
    ])
    |> validate_inclusion(:space_type, @space_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:quota_bytes, greater_than_or_equal_to: 0)
    |> validate_two_axis_invariants()
  end

  def writable?(%__MODULE__{status: "active"}), do: true
  def writable?(%__MODULE__{}), do: false

  def readable?(%__MODULE__{status: status}) when status in ~w(active suspended archived),
    do: true

  def readable?(%__MODULE__{}), do: false

  defp validate_two_axis_invariants(changeset) do
    is_local = get_field(changeset, :is_local)
    space_type = get_field(changeset, :space_type)

    changeset
    |> then(fn cs ->
      if is_local == true and space_type != "personal" do
        add_error(cs, :space_type, "must be personal when is_local is true")
      else
        cs
      end
    end)
    |> then(fn cs ->
      if space_type == "org" and is_local == true do
        add_error(cs, :is_local, "must be false when space_type is org")
      else
        cs
      end
    end)
  end
end
