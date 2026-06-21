defmodule MatomeApiWeb.RecordingController do
  use MatomeApiWeb, :controller

  alias MatomeApi.Content
  alias MatomeApi.Storage.Presigner

  def index(conn, params) do
    json(conn, %{
      recordings:
        Enum.map(Content.list_recordings(conn.assigns.current_user, params), &recording_json/1)
    })
  end

  def search(conn, params), do: index(conn, params)

  def show(conn, %{"id" => id}) do
    case Content.get_recording(conn.assigns.current_user, id) do
      nil -> not_found(conn)
      recording -> json(conn, %{recording: recording_json(recording)})
    end
  end

  def create(conn, params) do
    case Content.create_recording(conn.assigns.current_user, params) do
      {:ok, recording} ->
        presign_create(conn, recording, params)

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: errors_on(changeset)})
    end
  end

  defp presign_create(conn, recording, params) do
    presign_opts = upload_presign_opts(params)

    case Presigner.presign_upload(recording.storage_key, presign_opts) do
      {:ok, upload} ->
        conn
        |> put_status(:created)
        |> json(%{recording: recording_json(recording), upload: upload})

      {:error, :too_large} ->
        conn
        |> put_status(:request_entity_too_large)
        |> json(%{error: "upload_too_large", max_bytes: Presigner.max_upload_bytes()})

      {:error, :invalid_content_length} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{content_length: ["is invalid"]}})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: to_string(reason)})
    end
  end

  defp upload_presign_opts(params) do
    case parse_content_length(params["content_length"]) do
      nil -> []
      :invalid -> [content_length: :invalid]
      bytes -> [content_length: bytes]
    end
  end

  defp parse_content_length(nil), do: nil
  defp parse_content_length(bytes) when is_integer(bytes), do: bytes

  defp parse_content_length(bytes) when is_binary(bytes) do
    case Integer.parse(bytes) do
      {parsed, ""} -> parsed
      _ -> :invalid
    end
  end

  defp parse_content_length(_bytes), do: :invalid

  def update(conn, %{"id" => id} = params) do
    case Content.update_recording(conn.assigns.current_user, id, params) do
      nil ->
        not_found(conn)

      {:ok, recording} ->
        json(conn, %{recording: recording_json(recording)})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: errors_on(changeset)})
    end
  end

  def process(conn, %{"id" => id}) do
    case Content.enqueue_recording_processing(conn.assigns.current_user, id) do
      nil ->
        not_found(conn)

      {:ok, recording} ->
        conn
        |> put_status(:accepted)
        |> json(%{recording: recording_json(recording), processing: %{queued: true}})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: errors_on(changeset)})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Content.delete_recording(conn.assigns.current_user, id) do
      nil ->
        not_found(conn)

      {:ok, _recording} ->
        send_resp(conn, :no_content, "")

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: errors_on(changeset)})
    end
  end

  def download_url(conn, %{"id" => id}) do
    with %{} = recording <- Content.get_recording(conn.assigns.current_user, id),
         {:ok, download} <- Presigner.presign_download(recording.storage_key) do
      json(conn, %{download: download})
    else
      nil -> not_found(conn)
      {:error, _reason} -> not_found(conn)
    end
  end

  defp recording_json(recording) do
    %{
      id: recording.id,
      owner_id: recording.owner_id,
      title: recording.title,
      summary: recording.summary,
      transcript: recording.transcript,
      notes: recording.notes,
      media_type: recording.media_type,
      storage_key: recording.storage_key,
      status: Atom.to_string(recording.status),
      error_reason: recording.error_reason,
      duration: recording.duration,
      badge: recording.badge,
      workspace_id: recording.workspace_id,
      matome_id: recording.matome_id,
      inserted_at: recording.inserted_at,
      updated_at: recording.updated_at
    }
  end

  defp not_found(conn), do: conn |> put_status(:not_found) |> json(%{error: "not_found"})

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
