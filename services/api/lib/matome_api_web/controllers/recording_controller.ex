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
        upload = Presigner.presign_upload(recording.storage_key)

        conn
        |> put_status(:created)
        |> json(%{recording: recording_json(recording), upload: upload})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: errors_on(changeset)})
    end
  end

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
    case Content.get_recording(conn.assigns.current_user, id) do
      nil -> not_found(conn)
      recording -> json(conn, %{download: Presigner.presign_download(recording.storage_key)})
    end
  end

  defp recording_json(recording) do
    %{
      id: recording.id,
      owner_id: recording.owner_id,
      title: recording.title,
      summary: recording.summary,
      transcript: recording.transcript,
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
