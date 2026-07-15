defmodule MatomeApi.Content.Item do
  use Ecto.Schema
  import Ecto.Changeset

  alias MatomeApi.Auth.User
  alias MatomeApi.Content.{FileBlob, Matome, TextContent, Workspace}

  @item_types [:file, :text]
  @processing_states [:not_requested, :queued, :processing, :succeeded, :failed]
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
    notes
    processing_config_revision
    processing_error
    processing_outputs
    processing_run_id
    processing_state
    source_revision
    status
    storage_key
    storageKey
    summary
    text_content_id
    textContentId
    title
    transcript
    upload_generation
    upload_state
    workspace_id
    workspaceId
  )

  schema "items" do
    field :position, :integer
    field :item_type, Ecto.Enum, values: @item_types
    field :title, :string, default: "Untitled"
    field :notes, :string
    field :metadata, :map, default: %{}
    field :client_id, :string
    field :client_fingerprint, :string
    field :processing_state, Ecto.Enum, values: @processing_states, default: :not_requested
    field :processing_run_id, Ecto.UUID
    field :source_revision, :integer, default: 1
    field :processing_config_revision, :integer
    field :processing_outputs, :map, default: %{}
    field :processing_error, :map

    belongs_to :owner, User
    belongs_to :workspace, Workspace
    belongs_to :matome, Matome
    belongs_to :file_blob, FileBlob
    belongs_to :text_content, TextContent

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :owner_id,
      :client_id,
      :client_fingerprint,
      :workspace_id,
      :matome_id,
      :position,
      :item_type,
      :title,
      :notes,
      :metadata,
      :processing_state,
      :processing_run_id,
      :source_revision,
      :processing_config_revision,
      :processing_outputs,
      :processing_error,
      :file_blob_id,
      :text_content_id
    ])
    |> update_change(:title, &String.trim/1)
    |> validate_required([:owner_id, :item_type, :title, :metadata, :processing_state])
    |> validate_length(:title, min: 1, max: 255)
    |> validate_length(:client_id, min: 1, max: 255)
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> validate_number(:source_revision, greater_than: 0)
    |> validate_number(:processing_config_revision, greater_than_or_equal_to: 0)
    |> validate_metadata_render_hints_only()
    |> foreign_key_constraint(:workspace_id, name: :items_owner_workspace_fkey)
    |> foreign_key_constraint(:matome_id, name: :items_owner_matome_fkey)
    |> foreign_key_constraint(:file_blob_id)
    |> foreign_key_constraint(:text_content_id)
    |> unique_constraint(:position, name: :items_matome_id_position_index)
    |> unique_constraint([:owner_id, :client_id], name: :items_owner_id_client_id_index)
    |> unique_constraint(:file_blob_id, name: :items_file_blob_id_index)
    |> unique_constraint(:text_content_id, name: :items_text_content_id_index)
    |> check_constraint(:item_type, name: :items_item_type_check)
    |> check_constraint(:item_type, name: :items_payload_exclusive_arc_check)
    |> check_constraint(:position, name: :items_position_check)
    |> check_constraint(:client_id, name: :items_client_identity_check)
    |> check_constraint(:processing_state, name: :items_processing_state_check)
    |> check_constraint(:processing_run_id, name: :items_processing_run_check)
    |> check_constraint(:source_revision, name: :items_processing_revision_check)
    |> check_constraint(:metadata, name: :items_metadata_check)
    |> check_constraint(:processing_outputs, name: :items_processing_outputs_check)
    |> check_constraint(:processing_error, name: :items_processing_error_check)
  end

  def processing_changeset(item, attrs) do
    item
    |> cast(attrs, [
      :processing_state,
      :processing_run_id,
      :processing_config_revision,
      :processing_outputs,
      :processing_error
    ])
    |> validate_required([:processing_state])
    |> validate_number(:processing_config_revision, greater_than_or_equal_to: 0)
    |> check_constraint(:processing_state, name: :items_processing_state_check)
    |> check_constraint(:processing_run_id, name: :items_processing_run_check)
    |> check_constraint(:processing_outputs, name: :items_processing_outputs_check)
    |> check_constraint(:processing_error, name: :items_processing_error_check)
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
