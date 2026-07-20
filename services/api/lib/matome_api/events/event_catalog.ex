defmodule MatomeApi.Events.EventCatalog do
  @moduledoc """
  Collection policy for one stable, versioned event key.

  Identity, class, lock state, and detail keys are migration-owned. Runtime
  changes are limited to enablement, description, and retention.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @classes ~w(security operational product)
  @retention_floors %{"security" => 365, "operational" => 90, "product" => 30}

  @primary_key {:key, :string, autogenerate: false}
  schema "event_catalog" do
    field :event_class, :string
    field :enabled, :boolean
    field :description, :string
    field :retention_days, :integer
    field :locked, :boolean
    field :detail_keys, {:array, :string}, default: []

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(catalog, attrs) do
    catalog
    |> cast(attrs, [:enabled, :description, :retention_days])
    |> validate_required([:enabled, :description, :retention_days])
    |> validate_length(:description, min: 1, max: 500)
    |> validate_number(:retention_days, greater_than: 0)
    |> validate_policy()
    |> check_constraint(:retention_days, name: :event_catalog_retention_floor)
    |> check_constraint(:enabled, name: :event_catalog_security_policy)
  end

  def classes, do: @classes

  defp validate_policy(changeset) do
    event_class = changeset.data.event_class
    floor = Map.fetch!(@retention_floors, event_class)

    changeset
    |> validate_number(:retention_days,
      greater_than_or_equal_to: floor,
      message: "must be at least #{floor} days for #{event_class} events"
    )
    |> then(fn changeset ->
      if changeset.data.locked and get_field(changeset, :enabled) == false do
        add_error(changeset, :enabled, "cannot disable a locked event")
      else
        changeset
      end
    end)
  end
end
