defmodule MatomeApi.Events.Event do
  @moduledoc """
  One immutable security, operational, or product event.

  Catalog class and retention expiry are snapshotted by the database insert
  trigger. There is intentionally no update changeset or `updated_at` field.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MatomeApi.Events

  @severities ~w(info warning error critical)
  @writable_fields [
    :event_key,
    :severity,
    :actor_id,
    :actor_email,
    :owner_id,
    :subject_type,
    :subject_id,
    :device_id,
    :run_id,
    :correlation_id,
    :source_type,
    :source_id,
    :remote_ip,
    :details,
    :occurred_at
  ]

  schema "events" do
    field :event_key, :string
    field :event_class, :string, read_after_writes: true
    field :severity, :string, default: "info"
    field :actor_id, :integer
    field :actor_email, :string
    field :owner_id, :integer
    field :subject_type, :string
    field :subject_id, :string
    field :device_id, :integer
    field :run_id, Ecto.UUID
    field :correlation_id, :string
    field :source_type, :string, default: "core"
    field :source_id, :string, default: "core"
    field :remote_ip, :string
    field :details, :map, default: %{}
    field :occurred_at, :utc_datetime_usec
    field :retention_until, :utc_datetime_usec, read_after_writes: true

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, @writable_fields)
    |> put_default_occurred_at()
    |> validate_required([:event_key, :severity, :source_type, :source_id, :details, :occurred_at])
    |> validate_inclusion(:severity, @severities)
    |> validate_length(:actor_email, max: 320)
    |> validate_length(:subject_type, max: 100)
    |> validate_length(:subject_id, max: 255)
    |> validate_length(:correlation_id, max: 255)
    |> validate_length(:source_type, max: 100)
    |> validate_length(:source_id, max: 255)
    |> validate_length(:remote_ip, max: 64)
    |> validate_subject_pair()
    |> validate_details()
    |> foreign_key_constraint(:event_key)
    |> check_constraint(:severity, name: :events_severity)
    |> check_constraint(:subject_type, name: :events_subject_pair)
  end

  defp put_default_occurred_at(changeset) do
    case get_field(changeset, :occurred_at) do
      nil -> put_change(changeset, :occurred_at, DateTime.utc_now())
      _occurred_at -> changeset
    end
  end

  defp validate_subject_pair(changeset) do
    case {get_field(changeset, :subject_type), get_field(changeset, :subject_id)} do
      {nil, nil} -> changeset
      {type, id} when is_binary(type) and is_binary(id) -> changeset
      _pair -> add_error(changeset, :subject_id, "must be set together with subject_type")
    end
  end

  defp validate_details(changeset) do
    key = get_field(changeset, :event_key)
    details = get_field(changeset, :details, %{})

    with {:ok, allowed} <- Events.detail_keys(key),
         {:ok, normalized} <- normalize_details(details),
         true <- MapSet.subset?(MapSet.new(Map.keys(normalized)), MapSet.new(allowed)),
         true <- Enum.all?(normalized, fn {_key, value} -> bounded_value?(value) end),
         {:ok, encoded} <- Jason.encode(normalized),
         true <- byte_size(encoded) <= 4096 do
      put_change(changeset, :details, normalized)
    else
      :error -> add_error(changeset, :event_key, "is not a code-defined event key")
      {:error, :invalid_details} -> add_error(changeset, :details, "must use string or atom keys")
      false -> add_error(changeset, :details, "contains unknown, nested, or oversized values")
      {:error, _reason} -> add_error(changeset, :details, "must be JSON encodable")
    end
  end

  defp normalize_details(details) when is_map(details) do
    Enum.reduce_while(details, {:ok, %{}}, fn
      {key, value}, {:ok, acc} when is_binary(key) or is_atom(key) ->
        {:cont, {:ok, Map.put(acc, to_string(key), value)}}

      _entry, _acc ->
        {:halt, {:error, :invalid_details}}
    end)
  end

  defp normalize_details(_details), do: {:error, :invalid_details}

  defp bounded_value?(value) when is_binary(value), do: byte_size(value) <= 512
  defp bounded_value?(value) when is_boolean(value) or is_number(value) or is_nil(value), do: true

  defp bounded_value?(values) when is_list(values) and length(values) <= 50,
    do: Enum.all?(values, &bounded_value?/1)

  defp bounded_value?(_value), do: false
end
