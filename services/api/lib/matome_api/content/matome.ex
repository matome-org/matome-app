defmodule MatomeApi.Content.Matome do
  use Ecto.Schema
  import Ecto.Changeset

  alias MatomeApi.Auth.User
  alias MatomeApi.Content.{Item, MatomeContact, Workspace}

  schema "matomes" do
    field :client_id, :string
    field :client_fingerprint, :string
    field :title, :string
    field :happened_at, :utc_datetime
    field :description, :string
    field :aggregated_summary, :string
    # Soft-delete (archive) marker (W3, task #1409). NULL ⟺ active; a timestamp
    # ⟺ archived. Set only via the archive/restore changesets, never user attrs.
    field :archived_at, :utc_datetime

    belongs_to :owner, User
    belongs_to :workspace, Workspace
    has_many :items, Item
    has_many :matome_contacts, MatomeContact

    timestamps(type: :utc_datetime)
  end

  # Reject happened_at values outside a sane window: roughly the digital era
  # through a year out. Anything beyond is garbage (parser default years, typos).
  @happened_at_min ~U[2000-01-01 00:00:00Z]
  @happened_at_max_offset_seconds 366 * 24 * 60 * 60

  def changeset(matome, attrs) do
    matome
    |> cast(attrs, [
      :title,
      :happened_at,
      :description,
      :aggregated_summary,
      :workspace_id
    ])
    |> update_change(:title, &trim/1)
    |> validate_required([:title])
    |> validate_length(:title, min: 1, max: 255)
    |> validate_happened_at()
    |> foreign_key_constraint(:workspace_id)
  end

  def create_changeset(matome, attrs) do
    matome
    |> changeset(attrs)
    |> cast(attrs, [:client_id, :client_fingerprint])
    |> validate_length(:client_id, min: 1, max: 255)
    |> validate_format(:client_id, ~r/\S/, message: "can't be blank")
    |> unique_constraint([:owner_id, :client_id], name: :matomes_owner_id_client_id_index)
    |> check_constraint(:client_id, name: :matomes_client_identity_check)
  end

  @doc """
  Changeset that toggles the soft-delete marker. `archived?` true stamps
  `archived_at` with the supplied time (defaulting to now); false clears it.
  """
  def archive_changeset(matome, archived?, now \\ DateTime.utc_now()) do
    archived_at = if archived?, do: DateTime.truncate(now, :second), else: nil
    change(matome, archived_at: archived_at)
  end

  defp trim(value) when is_binary(value), do: String.trim(value)
  defp trim(value), do: value

  defp validate_happened_at(changeset) do
    case get_change(changeset, :happened_at) do
      nil ->
        changeset

      %DateTime{} = happened_at ->
        max = DateTime.add(DateTime.utc_now(), @happened_at_max_offset_seconds, :second)

        cond do
          DateTime.compare(happened_at, @happened_at_min) == :lt ->
            add_error(changeset, :happened_at, "is too far in the past")

          DateTime.compare(happened_at, max) == :gt ->
            add_error(changeset, :happened_at, "is too far in the future")

          true ->
            changeset
        end
    end
  end
end
