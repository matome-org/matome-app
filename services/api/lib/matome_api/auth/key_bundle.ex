defmodule MatomeApi.Auth.KeyBundle do
  @moduledoc """
  A user's zero-knowledge key bundle: opaque, client-wrapped copies of their
  DEK plus the salts/params needed to re-derive a KEK. Every `wrapped_*` and
  `salt_*` field is treated as an opaque blob — this schema does not (and,
  by design, cannot) interpret their contents. See
  `.docs/internal/at-rest-key-flow.md` Appendix A for the frozen wire format.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @required_fields ~w(
    wrapped_dek_pw wrapped_dek_recovery salt_enc salt_rec salt_auth kdf_params user_id
  )a

  schema "key_bundles" do
    field :wrapped_dek_pw, :string
    field :wrapped_dek_recovery, :string
    field :salt_enc, :string
    field :salt_rec, :string
    field :salt_auth, :string
    field :kdf_params, :map

    belongs_to :user, MatomeApi.Auth.User

    timestamps(type: :utc_datetime)
  end

  def changeset(key_bundle, attrs) do
    key_bundle
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:user_id)
  end

  @doc "Fields replaced on conflict when upserting (see `MatomeApi.Auth.upsert_key_bundle/2`)."
  def upsert_replace_fields do
    [
      :wrapped_dek_pw,
      :wrapped_dek_recovery,
      :salt_enc,
      :salt_rec,
      :salt_auth,
      :kdf_params,
      :updated_at
    ]
  end
end
