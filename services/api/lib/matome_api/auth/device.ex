defmodule MatomeApi.Auth.Device do
  @moduledoc """
  A device a user has logged in from (W4 #1872, plan p2-core-backoffice
  §9.5). Feeds the sessions view (W6) and revocation (W5).

  Correlation key: `(user_id, client_id)` where `client_id` is a stable
  UUID the client generates once and sends as `device.id` on login. It is
  unique per user, not globally — the same physical device used by two
  accounts is two rows. When a client sends no identifier, `client_id` is
  NULL and correlation degrades to the user-agent string (see
  `MatomeApi.Auth.resolve_device/3`).

  `form_factor` / `device_class` / `model` are client-declared access
  metadata for the admin dashboard (normalized via `DeviceMeta`).

  `device_key_enrolled` marks whether an E2E device key has been enrolled
  for this device (consumed by the key-bundle flow; written by a later
  wave). `revoked_at` is the W5 revocation seam — capture never sets it.

  Retention of the PII here (user agent, and the per-token IPs referencing
  this row) is bounded — see `services/api/docs/session-metadata-retention.md`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "devices" do
    field :client_id, Ecto.UUID
    field :platform, :string
    field :form_factor, :string
    field :device_class, :string
    field :model, :string
    field :display_name, :string
    field :user_agent, :string
    field :first_seen_at, :utc_datetime
    field :last_seen_at, :utc_datetime
    field :device_key_enrolled, :boolean, default: false
    field :revoked_at, :utc_datetime

    belongs_to :user, MatomeApi.Auth.User

    timestamps(type: :utc_datetime)
  end

  def changeset(device, attrs) do
    device
    |> cast(attrs, [
      :user_id,
      :client_id,
      :platform,
      :form_factor,
      :device_class,
      :model,
      :display_name,
      :user_agent,
      :first_seen_at,
      :last_seen_at,
      :device_key_enrolled,
      :revoked_at
    ])
    |> validate_required([:user_id, :first_seen_at, :last_seen_at])
    |> validate_length(:platform, max: 100)
    |> validate_length(:form_factor, max: 100)
    |> validate_length(:device_class, max: 100)
    |> validate_length(:model, max: 255)
    |> validate_length(:display_name, max: 255)
    |> unique_constraint([:user_id, :client_id])
  end
end
