defmodule MatomeApiWeb.ItemController do
  use MatomeApiWeb, :controller

  require Logger

  alias MatomeApi.Content
  alias MatomeApi.Storage.UploadPolicy

  def index(conn, %{"matome_id" => matome_id}) do
    case Content.list_items(conn.assigns.current_user, matome_id) do
      nil -> not_found(conn)
      items -> json(conn, %{items: Enum.map(items, &item_json/1)})
    end
  end

  def index(conn, _params),
    do:
      json(conn, %{items: Enum.map(Content.list_items(conn.assigns.current_user), &item_json/1)})

  def show(conn, %{"id" => id}) do
    case Content.get_item(conn.assigns.current_user, id) do
      nil -> not_found(conn)
      item -> json(conn, %{item: item_json(item)})
    end
  end

  def create(conn, %{"matome_id" => matome_id, "item_type" => "text"} = params) do
    create_text(conn, Map.put(params, "matome_id", matome_id))
  end

  def create(conn, %{"matome_id" => _matome_id, "item_type" => "file"} = params),
    do: create_file(conn, params)

  def create_text(conn, params) do
    with :ok <- require_nonblank(params, "client_id"),
         :ok <- require_nonblank(params, "body") do
      case Content.create_text_item(conn.assigns.current_user, params["matome_id"], params) do
        nil ->
          not_found(conn)

        {:ok, item} ->
          conn |> put_status(:created) |> json(%{contract_version: "1", item: item_json(item)})

        {:error, {:client_id_conflict, item}} ->
          client_id_conflict(conn, item)

        {:error, changeset} ->
          validation_error(conn, changeset)
      end
    else
      {:error, field} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{field => ["can't be blank"]}})
    end
  end

  def update_text(conn, %{"id" => id, "body" => body, "expected_source_revision" => revision})
      when is_binary(body) and is_integer(revision) and revision > 0 do
    case Content.update_text_item(conn.assigns.current_user, id, body, revision) do
      nil ->
        not_found(conn)

      {:ok, item} ->
        json(conn, %{item: item_json(item)})

      {:error, {:version_conflict, item}} ->
        version_conflict(conn, item)

      {:error, :item_type_mismatch} ->
        type_error(conn)

      {:error, %Ecto.Changeset{} = changeset} ->
        validation_error(conn, changeset)
    end
  end

  def update_text(conn, _params), do: invalid_text_mutation(conn)

  def delete_text(conn, %{"id" => id, "expected_source_revision" => revision})
      when is_integer(revision) and revision > 0 do
    case Content.delete_text_item(conn.assigns.current_user, id, revision) do
      nil ->
        not_found(conn)

      {:ok, _item} ->
        send_resp(conn, :no_content, "")

      {:error, {:version_conflict, item}} ->
        version_conflict(conn, item)

      {:error, :item_type_mismatch} ->
        type_error(conn)

      {:error, reason} ->
        Logger.error("text item delete failed: #{MatomeApi.LogRedaction.redact(reason)}")
        conn |> put_status(:unprocessable_entity) |> json(%{error: "delete_failed"})
    end
  end

  def delete_text(conn, _params), do: invalid_text_mutation(conn)

  defp create_file(conn, %{"matome_id" => matome_id} = params) do
    case Content.create_file_item(conn.assigns.current_user, matome_id, params) do
      nil ->
        not_found(conn)

      {:ok, item} ->
        upload_result =
          if UploadPolicy.mode_for(item.file_blob.media_type, item.file_blob.byte_size) ==
               :multipart do
            Content.request_item_upload(conn.assigns.current_user, item.id, %{
              "mode" => "auto",
              "transport" => Map.get(params, "transport")
            })
          else
            with {:ok, presign} <- Content.presign_item_upload(conn.assigns.current_user, item.id) do
              {:ok, upload_json(item, presign)}
            end
          end

        case upload_result do
          {:ok, upload} ->
            conn
            |> put_status(:created)
            |> json(%{
              contract_version: "1",
              item: item_json(item),
              upload: upload
            })

          {:error, reason} ->
            conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
        end

      {:error, :quota_exceeded} ->
        conn |> put_status(:request_entity_too_large) |> json(%{error: "quota_exceeded"})

      {:error, :space_not_writable} ->
        conn |> put_status(:forbidden) |> json(%{error: "space_not_writable"})

      {:error, {:client_id_conflict, _item}} ->
        conn |> put_status(:conflict) |> json(%{error: "client_id_conflict"})

      {:error, reason} when is_atom(reason) ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})

      {:error, changeset} ->
        validation_error(conn, changeset)
    end
  end

  def presign(conn, %{"id" => id} = params) do
    case Content.presign_item_upload(conn.assigns.current_user, id, params) do
      nil ->
        not_found(conn)

      {:ok, presign} ->
        json(conn, %{presign: presign_json(presign)})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
    end
  end

  def download_url(conn, %{"id" => id}) do
    case Content.presign_item_download(conn.assigns.current_user, id) do
      nil ->
        not_found(conn)

      {:ok, presign} ->
        conn
        |> put_resp_header("cache-control", "private, no-store")
        |> json(%{download: presign_json(presign)})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Content.update_item(conn.assigns.current_user, id, params) do
      nil ->
        not_found(conn)

      {:ok, item} ->
        json(conn, %{item: item_json(item)})

      {:error, reason} when is_atom(reason) ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})

      {:error, changeset} ->
        validation_error(conn, changeset)
    end
  end

  def process(conn, %{"id" => id}) do
    case Content.enqueue_item_processing(conn.assigns.current_user, id) do
      nil ->
        not_found(conn)

      {:ok, item} ->
        conn
        |> put_status(:accepted)
        |> json(%{
          contract_version: "1",
          item: item_json(item),
          processing: %{
            queued: item.processing_state == :queued,
            state: Atom.to_string(item.processing_state)
          }
        })

      {:error, :capabilities_unavailable} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: "capabilities_unavailable"})

      {:error, %Ecto.Changeset{} = changeset} ->
        validation_error(conn, changeset)

      {:error, reason} when is_atom(reason) ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})

      {:error, _reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "processing_request_failed"})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Content.delete_item(conn.assigns.current_user, id) do
      nil ->
        not_found(conn)

      {:ok, _item} ->
        send_resp(conn, :no_content, "")

      {:error, :text_endpoint_required} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "text_endpoint_required"})

      {:error, reason} ->
        Logger.error("item delete failed: #{MatomeApi.LogRedaction.redact(reason)}")
        conn |> put_status(:unprocessable_entity) |> json(%{error: "delete_failed"})
    end
  end

  defp item_json(item) do
    %{
      id: item.id,
      owner_id: item.owner_id,
      client_id: item.client_id,
      workspace_id: item.workspace_id,
      matome_id: item.matome_id,
      position: item.position,
      item_type: Atom.to_string(item.item_type),
      title: item.title,
      notes: item.notes,
      metadata: item.metadata,
      processing_state: Atom.to_string(item.processing_state),
      processing_run_id: item.processing_run_id,
      processing_attempt: item.processing_attempt,
      source_revision: item.source_revision,
      processing_config_revision: item.processing_config_revision,
      processing_capabilities: item.processing_capabilities,
      processing_requested_outputs: item.processing_requested_outputs,
      processing_requested_at: item.processing_requested_at,
      processing_deadline_at: item.processing_deadline_at,
      processing_outputs: item.processing_outputs,
      processing_error: item.processing_error,
      file: file_json(item.file_blob),
      text: text_json(item.text_content),
      inserted_at: item.inserted_at,
      updated_at: item.updated_at
    }
  end

  defp file_json(nil), do: nil

  defp file_json(file_blob) do
    %{
      id: file_blob.id,
      filename: file_blob.filename,
      original_extension: file_blob.original_extension,
      content_type: file_blob.content_type,
      byte_size: file_blob.byte_size,
      checksum_sha256: file_blob.checksum_sha256,
      media_type: file_blob.media_type,
      duration: file_blob.duration,
      upload_state: file_blob.upload_state,
      upload_generation: file_blob.upload_generation,
      uploaded_at: file_blob.uploaded_at,
      open_policy: file_blob.open_policy
    }
  end

  defp text_json(nil), do: nil
  defp text_json(text_content), do: %{id: text_content.id, body: text_content.body}

  defp upload_json(item, presign) do
    headers =
      case presign.content_length do
        nil -> %{}
        content_length -> %{"content-length" => to_string(content_length)}
      end

    %{
      upload_id: "item-#{item.id}-upload-#{item.file_blob.upload_generation}",
      upload_generation: item.file_blob.upload_generation,
      mode: "single",
      transport: "direct_signed_length",
      state: item.file_blob.upload_state,
      expires_at: presign.expires_at,
      request: %{
        method: presign.method,
        url: presign.url,
        headers: headers
      }
    }
  end

  defp presign_json(presign) do
    %{
      method: presign.method,
      url: presign.url,
      expires_in: presign.expires_in,
      expires_at: presign.expires_at,
      content_length: presign.content_length,
      max_bytes: presign.max_bytes
    }
    |> maybe_put(:filename, presign[:filename])
    |> maybe_put(:original_extension, presign[:original_extension])
    |> maybe_put(:content_type, presign[:content_type])
    |> maybe_put(:byte_size, presign[:byte_size])
    |> maybe_put(:open_policy, presign[:open_policy])
    |> maybe_put(:action, presign[:action])
    |> maybe_put(:warning, presign[:warning])
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp not_found(conn), do: conn |> put_status(:not_found) |> json(%{error: "not_found"})

  defp type_error(conn),
    do: conn |> put_status(:unprocessable_entity) |> json(%{error: "item_type_mismatch"})

  defp version_conflict(conn, item) do
    conn
    |> put_status(:conflict)
    |> json(%{error: "version_conflict", item: item_json(item)})
  end

  defp client_id_conflict(conn, item) do
    conn
    |> put_status(:conflict)
    |> json(%{error: "client_id_conflict", item: item_json(item)})
  end

  defp invalid_text_mutation(conn) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "invalid_text_mutation"})
  end

  defp require_nonblank(params, field) do
    case params[field] do
      value when is_binary(value) -> if String.trim(value) == "", do: {:error, field}, else: :ok
      _missing -> {:error, field}
    end
  end

  defp validation_error(conn, changeset) do
    conn |> put_status(:unprocessable_entity) |> json(%{errors: errors_on(changeset)})
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
