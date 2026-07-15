defmodule MatomeApi.SystemConfig.Config do
  use Ecto.Schema
  import Ecto.Changeset

  alias MatomeApi.SystemConfig.Policy

  @primary_key false
  schema "system_configs" do
    field :key, :string, primary_key: true
    field :document, :map

    timestamps(type: :utc_datetime)
  end

  def changeset(config, attrs) do
    config
    |> cast(attrs, [:key, :document])
    |> validate_required([:key, :document])
    |> validate_inclusion(:key, ["global"])
    |> validate_document()
    |> check_constraint(:key, name: :system_configs_global_singleton)
    |> check_constraint(:document, name: :system_configs_document_v1)
  end

  defp validate_document(changeset) do
    case fetch_change(changeset, :document) do
      {:ok, document} ->
        case Policy.validate(document) do
          {:ok, document} -> put_change(changeset, :document, document)
          {:error, paths} -> add_error(changeset, :document, "is invalid", paths: paths)
        end

      :error ->
        changeset
    end
  end
end
