defmodule MatomeApi.Content.FileBlob do
  use Ecto.Schema
  import Ecto.Changeset

  alias MatomeApi.Storage.Presigner

  @media_types ~w(audio image document video)

  schema "file_blobs" do
    field :storage_key, :string
    field :byte_size, :integer
    field :media_type, :string
    field :duration, :integer
    field :transcript, :string
    field :summary, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(file_blob, attrs) do
    file_blob
    |> cast(attrs, [:storage_key, :byte_size, :media_type, :duration, :transcript, :summary])
    |> validate_required([:storage_key, :byte_size, :media_type])
    |> validate_number(:byte_size,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: Presigner.max_upload_bytes()
    )
    |> validate_number(:duration, greater_than_or_equal_to: 0)
    |> validate_inclusion(:media_type, @media_types)
    |> check_constraint(:media_type, name: :file_blobs_media_type_check)
  end
end
