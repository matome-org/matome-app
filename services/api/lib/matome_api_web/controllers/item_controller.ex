defmodule MatomeApiWeb.ItemController do
  use MatomeApiWeb, :controller

  require Logger

  alias MatomeApi.Content

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
    case Content.create_text_item(conn.assigns.current_user, matome_id, params) do
      nil -> not_found(conn)
      {:ok, item} -> conn |> put_status(:created) |> json(%{item: item_json(item)})
      {:error, changeset} -> validation_error(conn, changeset)
    end
  end

  def create(conn, %{"matome_id" => matome_id, "item_type" => "file"} = params) do
    case Content.create_file_item(conn.assigns.current_user, matome_id, params) do
      nil ->
        not_found(conn)

      {:ok, item} ->
        case Content.presign_item_upload(conn.assigns.current_user, item.id) do
          {:ok, presign} ->
            conn |> put_status(:created) |> json(%{item: item_json(item, presign)})

          {:error, reason} ->
            conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
        end

      {:error, :quota_exceeded} ->
        conn |> put_status(:request_entity_too_large) |> json(%{error: "quota_exceeded"})

      {:error, :space_not_writable} ->
        conn |> put_status(:forbidden) |> json(%{error: "space_not_writable"})

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
        json(conn, %{download: presign_json(presign)})

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
        |> json(%{item: item_json(item), processing: %{queued: true}})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Content.delete_item(conn.assigns.current_user, id) do
      nil ->
        not_found(conn)

      {:ok, _item} ->
        send_resp(conn, :no_content, "")

      {:error, reason} ->
        Logger.error("item delete failed: #{inspect(reason)}")
        conn |> put_status(:unprocessable_entity) |> json(%{error: "delete_failed"})
    end
  end

  defp item_json(item, presign \\ nil) do
    %{
      id: item.id,
      owner_id: item.matome && item.matome.owner_id,
      matome_id: item.matome_id,
      position: item.position,
      item_type: Atom.to_string(item.item_type),
      metadata: item.metadata,
      file: file_json(item.file_blob),
      text: text_json(item.text_content),
      inserted_at: item.inserted_at,
      updated_at: item.updated_at
    }
    |> maybe_put_presign(presign)
  end

  defp file_json(nil), do: nil

  defp file_json(file_blob) do
    %{
      id: file_blob.id,
      byte_size: file_blob.byte_size,
      media_type: file_blob.media_type,
      duration: file_blob.duration,
      transcript: file_blob.transcript,
      summary: file_blob.summary
    }
  end

  defp text_json(nil), do: nil
  defp text_json(text_content), do: %{id: text_content.id, body: text_content.body}

  defp maybe_put_presign(item, nil), do: item
  defp maybe_put_presign(item, presign), do: Map.put(item, :presign, presign_json(presign))

  defp presign_json(presign) do
    %{
      method: presign.method,
      url: presign.url,
      expires_in: presign.expires_in,
      content_length: presign.content_length,
      max_bytes: presign.max_bytes
    }
  end

  defp not_found(conn), do: conn |> put_status(:not_found) |> json(%{error: "not_found"})

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
