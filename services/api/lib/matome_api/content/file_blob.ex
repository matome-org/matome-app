defmodule MatomeApi.Content.FileBlob do
  use Ecto.Schema
  import Ecto.Changeset

  alias MatomeApi.Storage.UploadPolicy

  @media_types ~w(audio image document video)
  @upload_states ~w(pending uploading uploaded failed aborted)

  schema "file_blobs" do
    field :storage_key, :string
    field :filename, :string
    field :content_type, :string
    field :byte_size, :integer
    field :checksum_sha256, :string
    field :media_type, :string
    field :duration, :integer
    field :upload_state, :string, default: "pending"
    field :upload_generation, :integer, default: 1
    field :uploaded_at, :utc_datetime
    field :multipart_context, :map

    timestamps(type: :utc_datetime)
  end

  def changeset(file_blob, attrs) do
    file_blob
    |> cast(attrs, [
      :storage_key,
      :filename,
      :content_type,
      :byte_size,
      :checksum_sha256,
      :media_type,
      :duration,
      :upload_state,
      :upload_generation,
      :uploaded_at,
      :multipart_context
    ])
    |> validate_required([:storage_key, :byte_size, :media_type])
    |> validate_length(:filename, min: 1, max: 1024)
    |> validate_length(:content_type, min: 1, max: 255)
    |> validate_format(:checksum_sha256, ~r/^[0-9a-f]{64}$/)
    |> validate_number(:byte_size,
      greater_than: 0,
      less_than_or_equal_to: UploadPolicy.provider_max_bytes()
    )
    |> validate_media_size()
    |> validate_multipart_checksum()
    |> validate_number(:duration, greater_than_or_equal_to: 0)
    |> validate_number(:upload_generation, greater_than: 0)
    |> validate_inclusion(:media_type, @media_types)
    |> validate_inclusion(:upload_state, @upload_states)
    |> check_constraint(:media_type, name: :file_blobs_media_type_check)
    |> check_constraint(:byte_size, name: :file_blobs_byte_size_check)
    |> check_constraint(:filename, name: :file_blobs_filename_check)
    |> check_constraint(:content_type, name: :file_blobs_content_type_check)
    |> check_constraint(:checksum_sha256, name: :file_blobs_checksum_sha256_check)
    |> check_constraint(:upload_state, name: :file_blobs_upload_state_check)
    |> check_constraint(:upload_generation, name: :file_blobs_upload_generation_check)
    |> check_constraint(:uploaded_at, name: :file_blobs_uploaded_at_check)
    |> check_constraint(:multipart_context, name: :file_blobs_multipart_context_check)
  end

  defp validate_media_size(changeset) do
    case {get_field(changeset, :media_type), get_field(changeset, :byte_size)} do
      {media_type, byte_size} when is_binary(media_type) and is_integer(byte_size) ->
        case UploadPolicy.validate_size(media_type, byte_size) do
          :ok -> changeset
          {:error, reason} -> add_error(changeset, :byte_size, Atom.to_string(reason))
        end

      _ ->
        changeset
    end
  end

  defp validate_multipart_checksum(changeset) do
    media_type = get_field(changeset, :media_type)
    byte_size = get_field(changeset, :byte_size)

    if is_binary(media_type) and is_integer(byte_size) and
         UploadPolicy.mode_for(media_type, byte_size) == :multipart and
         is_nil(get_field(changeset, :checksum_sha256)) do
      add_error(changeset, :checksum_sha256, "is required for multipart upload")
    else
      changeset
    end
  end
end
