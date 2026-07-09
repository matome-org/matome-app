defmodule MatomeApi.Admin.AuditEvent do
  @moduledoc """
  One immutable admin audit record (W3 #1871).

  The table is append-only at the DB level (see the
  `create_admin_audit_events` migration): UPDATE/DELETE/TRUNCATE raise. No
  `updated_at` — rows are never updated. `actor_email` is snapshotted so the
  trail stays readable if the user row is later deleted.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "admin_audit_events" do
    belongs_to :actor, MatomeApi.Auth.User
    field :actor_email, :string
    field :action, :string
    field :metadata, :map, default: %{}
    field :remote_ip, :string

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:actor_id, :actor_email, :action, :metadata, :remote_ip])
    |> validate_required([:action])
  end
end
