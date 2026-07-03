defmodule MatomeApi.Content.Item do
  use Ecto.Schema
  import Ecto.Changeset

  alias MatomeApi.Content.{FileBlob, Matome, TextContent}

  @item_types [:file, :text]
  @metadata_reserved_keys ~w(
    body
    byte_size
    byteSize
    contact_id
    contact_ids
    contactId
    contactIds
    file_blob_id
    fileBlobId
    media_type
    mediaType
    storage_key
    storageKey
    summary
    text_content_id
    textContentId
    transcript
  )

  schema "items" do
    field :position, :integer
    field :item_type, Ecto.Enum, values: @item_types
    field :metadata, :map, default: %{}

    belongs_to :matome, Matome
    belongs_to :file_blob, FileBlob
    belongs_to :text_content, TextContent

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:matome_id, :position, :item_type, :metadata, :file_blob_id, :text_content_id])
    |> validate_required([:matome_id, :position, :item_type, :metadata])
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> validate_metadata_render_hints_only()
    |> foreign_key_constraint(:matome_id)
    |> foreign_key_constraint(:file_blob_id)
    |> foreign_key_constraint(:text_content_id)
    |> unique_constraint(:position, name: :items_matome_id_position_index)
    |> unique_constraint(:file_blob_id, name: :items_file_blob_id_index)
    |> unique_constraint(:text_content_id, name: :items_text_content_id_index)
    |> check_constraint(:item_type, name: :items_item_type_check)
    |> check_constraint(:item_type, name: :items_payload_exclusive_arc_check)
  end

  defp validate_metadata_render_hints_only(changeset) do
    metadata = get_field(changeset, :metadata) || %{}

    reserved =
      metadata
      |> Map.keys()
      |> Enum.map(&to_string/1)
      |> Enum.filter(&(&1 in @metadata_reserved_keys))

    case reserved do
      [] ->
        changeset

      keys ->
        add_error(
          changeset,
          :metadata,
          "contains reserved payload keys: #{Enum.join(keys, ", ")}"
        )
    end
  end
end
