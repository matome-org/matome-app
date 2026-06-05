defmodule MatomeApi.Content do
  import Ecto.Query

  alias Ecto.Changeset
  alias MatomeApi.AIEngine.DispatchJob
  alias MatomeApi.Auth.User
  alias MatomeApi.Content.{Recording, Workspace}
  alias MatomeApi.Repo

  def list_workspaces(%User{id: owner_id}, params \\ %{}) do
    Workspace
    |> where([workspace], workspace.owner_id == ^owner_id)
    |> search_by(:name, params["q"] || params[:q])
    |> order_by([workspace], asc: workspace.name)
    |> Repo.all()
  end

  def get_workspace(%User{id: owner_id}, id) do
    Repo.get_by(Workspace, id: id, owner_id: owner_id)
  end

  def create_workspace(%User{id: owner_id}, attrs) do
    %Workspace{owner_id: owner_id}
    |> Workspace.changeset(attrs)
    |> Repo.insert()
  end

  def update_workspace(%User{} = owner, id, attrs) do
    with %Workspace{} = workspace <- get_workspace(owner, id) do
      workspace
      |> Workspace.changeset(attrs)
      |> Repo.update()
    end
  end

  def delete_workspace(%User{} = owner, id) do
    with %Workspace{} = workspace <- get_workspace(owner, id) do
      Repo.delete(workspace)
    end
  end

  def list_recordings(%User{id: owner_id}, params \\ %{}) do
    Recording
    |> where([recording], recording.owner_id == ^owner_id)
    |> maybe_filter_workspace(params["workspace_id"] || params[:workspace_id])
    |> search_recordings(params["q"] || params[:q])
    |> order_by([recording], desc: recording.inserted_at)
    |> Repo.all()
  end

  def get_recording(%User{id: owner_id}, id) do
    Repo.get_by(Recording, id: id, owner_id: owner_id)
  end

  def create_recording(%User{} = owner, attrs) do
    %Recording{owner_id: owner.id}
    |> Recording.changeset(attrs)
    |> validate_workspace_owner(owner)
    |> Repo.insert()
    |> put_recording_storage_key()
  end

  def update_recording(%User{} = owner, id, attrs) do
    with %Recording{} = recording <- get_recording(owner, id) do
      changeset =
        recording
        |> Recording.changeset(attrs)
        |> validate_workspace_owner(owner)

      status_changed? = Changeset.get_change(changeset, :status) != nil

      changeset
      |> Repo.update()
      |> broadcast_recording_status(status_changed?)
    end
  end

  def enqueue_recording_processing(%User{} = owner, id) do
    with %Recording{} = recording <- get_recording(owner, id),
         {:ok, _job} <- %{recording_id: recording.id} |> DispatchJob.new() |> Oban.insert() do
      {:ok, recording}
    end
  end

  def mark_recording_processing(%Recording{} = recording) do
    recording
    |> Recording.changeset(%{status: "processing", error_reason: nil})
    |> Repo.update()
    |> broadcast_recording_status(true)
  end

  def apply_ai_result(job_id, %{"job_id" => body_job_id, "recording_id" => recording_id})
      when job_id != body_job_id do
    _ = recording_id
    {:error, :recording_mismatch}
  end

  def apply_ai_result(_job_id, %{"recording_id" => recording_id, "status" => "done"} = attrs) do
    with {:ok, id} <- parse_recording_id(recording_id),
         %Recording{} = recording <- Repo.get(Recording, id) do
      attrs =
        %{
          status: "done",
          title: attrs["title"],
          transcript: attrs["transcript"],
          summary: attrs["summary"],
          duration: attrs["duration"],
          badge: attrs["badge"],
          error_reason: nil
        }
        |> Enum.reject(fn {_key, value} -> is_nil(value) end)
        |> Map.new()

      recording
      |> Recording.changeset(attrs)
      |> Repo.update()
      |> broadcast_recording_status(recording.status != :done)
    else
      :error -> {:error, :recording_mismatch}
      nil -> :not_found
    end
  end

  def apply_ai_result(_job_id, %{"recording_id" => recording_id, "status" => "failed"} = attrs) do
    with {:ok, id} <- parse_recording_id(recording_id),
         %Recording{} = recording <- Repo.get(Recording, id) do
      recording
      |> Recording.changeset(%{
        status: "failed",
        error_reason:
          get_in(attrs, ["error", "message"]) || attrs["error_reason"] || "ai_processing_failed"
      })
      |> Repo.update()
      |> broadcast_recording_status(recording.status != :failed)
    else
      :error -> {:error, :recording_mismatch}
      nil -> :not_found
    end
  end

  def apply_ai_result(_job_id, _attrs), do: {:error, :recording_mismatch}

  def delete_recording(%User{} = owner, id) do
    with %Recording{} = recording <- get_recording(owner, id) do
      Repo.delete(recording)
    end
  end

  defp put_recording_storage_key({:ok, %Recording{} = recording}) do
    recording
    |> Changeset.change(storage_key: recording_storage_key(recording))
    |> Repo.update()
  end

  defp put_recording_storage_key(result), do: result

  defp broadcast_recording_status({:ok, %Recording{} = recording} = result, true) do
    MatomeApiWeb.Endpoint.broadcast("user:#{recording.owner_id}", "recording:status", %{
      recording_id: recording.id,
      status: Atom.to_string(recording.status),
      summary: recording.summary,
      transcript: recording.transcript,
      error_reason: recording.error_reason,
      duration: recording.duration,
      badge: recording.badge,
      updated_at: recording.updated_at
    })

    result
  end

  defp broadcast_recording_status(result, _status_changed?), do: result

  defp recording_storage_key(%Recording{id: id, owner_id: owner_id}) do
    "owners/#{owner_id}/recordings/#{id}/media"
  end

  defp validate_workspace_owner(changeset, owner) do
    workspace_id = Changeset.get_field(changeset, :workspace_id)

    cond do
      is_nil(workspace_id) -> changeset
      get_workspace(owner, workspace_id) -> changeset
      true -> Changeset.add_error(changeset, :workspace_id, "is invalid")
    end
  end

  defp parse_recording_id(id) when is_integer(id), do: {:ok, id}

  defp parse_recording_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {parsed, ""} -> {:ok, parsed}
      _ -> :error
    end
  end

  defp parse_recording_id(_id), do: :error

  defp maybe_filter_workspace(query, nil), do: query
  defp maybe_filter_workspace(query, ""), do: query

  defp maybe_filter_workspace(query, workspace_id),
    do: where(query, [recording], recording.workspace_id == ^workspace_id)

  defp search_by(query, _field, nil), do: query
  defp search_by(query, _field, ""), do: query

  defp search_by(query, field, term) do
    pattern = "%#{term}%"
    where(query, [row], ilike(field(row, ^field), ^pattern))
  end

  defp search_recordings(query, nil), do: query
  defp search_recordings(query, ""), do: query

  defp search_recordings(query, term) do
    pattern = "%#{term}%"

    where(
      query,
      [recording],
      ilike(recording.title, ^pattern) or ilike(recording.summary, ^pattern) or
        ilike(recording.transcript, ^pattern)
    )
  end
end
