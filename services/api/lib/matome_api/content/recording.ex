defmodule MatomeApi.Content.Recording do
  use Ecto.Schema
  import Ecto.Changeset

  alias MatomeApi.Auth.User
  alias MatomeApi.Content.{Matome, Workspace}

  @statuses [:pending, :processing, :done, :failed]

  # Upload trust boundary: the only media kinds Core will accept. A mislabeled
  # media_type is rejected at the changeset so it never reaches storage or the
  # AI engine. `nil` is allowed — media_type is optional and defaults downstream.
  @media_types ~w(audio meeting image document)

  @doc "Allowlisted media types accepted on a recording."
  def media_types, do: @media_types

  schema "recordings" do
    field :title, :string
    field :summary, :string
    field :transcript, :string
    field :notes, :string
    field :media_type, :string
    field :storage_key, :string
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :error_reason, :string
    field :duration, :integer
    field :byte_size, :integer
    field :badge, :string

    belongs_to :owner, User
    belongs_to :workspace, Workspace
    belongs_to :matome, Matome

    timestamps(type: :utc_datetime)
  end

  def changeset(recording, attrs) do
    recording
    |> cast(attrs, [
      :title,
      :summary,
      :transcript,
      :notes,
      :media_type,
      :status,
      :error_reason,
      :duration,
      :byte_size,
      :badge,
      :workspace_id,
      :matome_id
    ])
    |> validate_required([:title])
    |> validate_inclusion(:media_type, @media_types)
    |> validate_number(:duration, greater_than_or_equal_to: 0)
    |> validate_number(:byte_size, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:workspace_id)
    |> foreign_key_constraint(:matome_id)
    |> check_constraint(:status, name: :recordings_status_check)
  end
end
