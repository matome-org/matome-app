defmodule MatomeApi.Content.Recording do
  use Ecto.Schema
  import Ecto.Changeset

  alias MatomeApi.Auth.User
  alias MatomeApi.Content.Workspace

  @statuses [:pending, :processing, :done, :failed]

  schema "recordings" do
    field :title, :string
    field :summary, :string
    field :transcript, :string
    field :media_type, :string
    field :storage_key, :string
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :error_reason, :string
    field :duration, :integer
    field :badge, :string

    belongs_to :owner, User
    belongs_to :workspace, Workspace

    timestamps(type: :utc_datetime)
  end

  def changeset(recording, attrs) do
    recording
    |> cast(attrs, [
      :title,
      :summary,
      :transcript,
      :media_type,
      :status,
      :error_reason,
      :duration,
      :badge,
      :workspace_id
    ])
    |> validate_required([:title])
    |> validate_number(:duration, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:workspace_id)
    |> check_constraint(:status, name: :recordings_status_check)
  end
end
