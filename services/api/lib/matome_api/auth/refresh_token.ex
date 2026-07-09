defmodule MatomeApi.Auth.RefreshToken do
  @moduledoc """
  A stored refresh token plus its session metadata (enriched in W4 #1872).

  Rotation chain: every login mints a fresh `family_id`; every refresh
  keeps it and records the previous token's `jti` in `rotated_from`, so a
  logical session is one family and its history is the jti chain. Rotated
  tokens are retained with `revoked_at` set rather than deleted — that is
  what lets W5 tell "already-rotated token replayed" apart from garbage.

  `ip`/`user_agent`/`login_method`/`last_seen_at`/`device_id` are capture
  metadata; retention is bounded per
  `services/api/docs/session-metadata-retention.md`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "refresh_tokens" do
    field :token, :string
    field :expires_at, :utc_datetime
    field :ip, :string
    field :user_agent, :string
    field :login_method, :string
    field :last_seen_at, :utc_datetime
    field :revoked_at, :utc_datetime
    field :jti, :string
    field :family_id, Ecto.UUID
    field :rotated_from, :string

    belongs_to :user, MatomeApi.Auth.User
    belongs_to :device, MatomeApi.Auth.Device

    timestamps(type: :utc_datetime)
  end

  def changeset(refresh_token, attrs) do
    refresh_token
    |> cast(attrs, [
      :token,
      :user_id,
      :expires_at,
      :device_id,
      :ip,
      :user_agent,
      :login_method,
      :last_seen_at,
      :revoked_at,
      :jti,
      :family_id,
      :rotated_from
    ])
    |> validate_required([:token, :user_id, :expires_at])
    |> unique_constraint(:token)
  end
end
