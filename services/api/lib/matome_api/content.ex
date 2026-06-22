defmodule MatomeApi.Content do
  import Ecto.Query

  alias Ecto.Changeset
  alias MatomeApi.AIEngine.DispatchJob
  alias MatomeApi.Auth.User

  alias MatomeApi.Content.{
    Contact,
    Matome,
    MatomeContact,
    Recording,
    RecordingContact,
    Workspace
  }

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
    |> validate_matome_owner(owner)
    |> Repo.insert()
    |> put_recording_storage_key()
  end

  def update_recording(%User{} = owner, id, attrs) do
    with %Recording{} = recording <- get_recording(owner, id) do
      changeset =
        recording
        |> Recording.changeset(attrs)
        |> validate_workspace_owner(owner)
        |> validate_matome_owner(owner)

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

  ## Matomes

  def list_matomes(%User{id: owner_id}, params \\ %{}) do
    Matome
    |> where([matome], matome.owner_id == ^owner_id)
    |> where([matome], is_nil(matome.archived_at))
    |> maybe_filter_workspace(params["workspace_id"] || params[:workspace_id])
    |> search_by(:title, params["q"] || params[:q])
    |> order_by([matome], desc: matome.inserted_at)
    |> Repo.all()
    |> Repo.preload(:matome_contacts)
  end

  def get_matome(%User{id: owner_id}, id) do
    Matome
    |> where([matome], matome.id == ^id and matome.owner_id == ^owner_id)
    |> where([matome], is_nil(matome.archived_at))
    |> Repo.one()
    |> case do
      nil -> nil
      matome -> Repo.preload(matome, :matome_contacts)
    end
  end

  @doc """
  Loads an owner-scoped matome regardless of its archived state. Used by
  `restore_matome` (an archived matome is invisible to `get_matome`, so restore
  must look it up here). Still owner-scoped at the query level — a cross-owner
  actor gets `nil` (the controller maps that to 404).
  """
  def get_matome_including_archived(%User{id: owner_id}, id) do
    case Repo.get_by(Matome, id: id, owner_id: owner_id) do
      nil -> nil
      matome -> Repo.preload(matome, :matome_contacts)
    end
  end

  @doc """
  Soft-delete (archive) an owner-scoped matome: stamps `archived_at`. Returns
  `nil` for a missing/out-of-scope matome (404). Data and local files are
  retained — this is recoverable via `restore_matome`.
  """
  def archive_matome(%User{} = owner, id) do
    with %Matome{} = matome <- get_matome(owner, id) do
      matome
      |> Matome.archive_changeset(true)
      |> Repo.update()
      |> preload_matome_contacts()
    end
  end

  @doc """
  Restore (un-archive) an owner-scoped matome: clears `archived_at`. Looks the
  matome up including archived rows (an archived one is hidden from
  `get_matome`). Returns `nil` for a missing/out-of-scope matome (404).
  """
  def restore_matome(%User{} = owner, id) do
    with %Matome{} = matome <- get_matome_including_archived(owner, id) do
      matome
      |> Matome.archive_changeset(false)
      |> Repo.update()
      |> preload_matome_contacts()
    end
  end

  def create_matome(%User{} = owner, attrs) do
    %Matome{owner_id: owner.id}
    |> Matome.changeset(attrs)
    |> validate_workspace_owner(owner)
    |> Repo.insert()
    |> preload_matome_contacts()
  end

  def update_matome(%User{} = owner, id, attrs) do
    with %Matome{} = matome <- get_matome(owner, id) do
      matome
      |> Matome.changeset(attrs)
      |> validate_workspace_owner(owner)
      |> Repo.update()
      |> preload_matome_contacts()
    end
  end

  def delete_matome(%User{} = owner, id) do
    with %Matome{} = matome <- get_matome(owner, id) do
      Repo.delete(matome)
    end
  end

  def attach_contact(%User{} = owner, matome_id, contact_id, attrs \\ %{}) do
    with %Matome{} = matome <- get_matome(owner, matome_id),
         %Contact{} = contact <- get_contact(owner, contact_id) do
      %MatomeContact{}
      |> MatomeContact.changeset(
        Map.merge(attrs, %{"matome_id" => matome.id, "contact_id" => contact.id})
      )
      |> Repo.insert(
        on_conflict: {:replace, [:role, :updated_at]},
        conflict_target: [:matome_id, :contact_id]
      )
    end
  end

  def detach_contact(%User{} = owner, matome_id, contact_id) do
    with %Matome{} = matome <- get_matome(owner, matome_id),
         %Contact{} = contact <- get_contact(owner, contact_id),
         %MatomeContact{} = join <-
           Repo.get_by(MatomeContact, matome_id: matome.id, contact_id: contact.id) do
      Repo.delete(join)
    end
  end

  ## Recording ↔ Contact (direct file↔contact edge, #1472)

  @doc """
  Link an owner-scoped contact directly to an owner-scoped recording (file).

  SECURITY (Olivier): owner-scopes BOTH endpoints — the recording AND the
  contact must each belong to the actor BEFORE the join is written. An
  out-of-scope `recording_id` OR `contact_id` short-circuits the `with` and
  returns `nil` (the caller maps that to 404), so a user can never attach to —
  or, via the cross-owner read returning nothing, enumerate — another user's
  recordings or contacts. Idempotent: a re-link of an existing pair is a no-op
  upsert (the UNIQUE(recording_id, contact_id) target), mirroring
  `attach_contact`.
  """
  def link_contact_to_recording(%User{} = owner, recording_id, contact_id) do
    with %Recording{} = recording <- get_recording(owner, recording_id),
         %Contact{} = contact <- get_contact(owner, contact_id) do
      %RecordingContact{}
      |> RecordingContact.changeset(%{
        "recording_id" => recording.id,
        "contact_id" => contact.id
      })
      |> Repo.insert(
        on_conflict: {:replace, [:updated_at]},
        conflict_target: [:recording_id, :contact_id]
      )
    end
  end

  @doc """
  Remove a direct recording↔contact link. Owner-scopes BOTH endpoints (same
  proof as `link_contact_to_recording`): an out-of-scope id returns `nil`.
  """
  def unlink_contact_from_recording(%User{} = owner, recording_id, contact_id) do
    with %Recording{} = recording <- get_recording(owner, recording_id),
         %Contact{} = contact <- get_contact(owner, contact_id),
         %RecordingContact{} = join <-
           Repo.get_by(RecordingContact, recording_id: recording.id, contact_id: contact.id) do
      Repo.delete(join)
    end
  end

  @doc """
  The contacts linked DIRECTLY (via `recording_contacts`) to an owner-scoped
  recording, display-name ascending. Owner-scoped on the recording: a
  cross-owner read returns `nil` (the security proof — another user's links are
  invisible).
  """
  def list_contacts_for_recording(%User{} = owner, recording_id) do
    with %Recording{} = recording <- get_recording(owner, recording_id) do
      Contact
      |> join(:inner, [contact], rc in RecordingContact,
        on: rc.contact_id == contact.id and rc.recording_id == ^recording.id
      )
      |> order_by([contact], asc: contact.display_name)
      |> Repo.all()
    end
  end

  @doc """
  The recordings (files) linked DIRECTLY (via `recording_contacts`) to an
  owner-scoped contact, newest first. Owner-scoped on the contact: a cross-owner
  read returns `nil`.
  """
  def list_recordings_for_contact(%User{} = owner, contact_id) do
    with %Contact{} = contact <- get_contact(owner, contact_id) do
      Recording
      |> join(:inner, [recording], rc in RecordingContact,
        on: rc.recording_id == recording.id and rc.contact_id == ^contact.id
      )
      |> order_by([recording], desc: recording.inserted_at)
      |> Repo.all()
    end
  end

  ## Contacts

  def list_contacts(%User{id: owner_id}, params \\ %{}) do
    Contact
    |> where([contact], contact.owner_id == ^owner_id)
    |> search_by(:display_name, params["q"] || params[:q])
    |> order_by([contact], asc: contact.display_name)
    |> Repo.all()
  end

  def get_contact(%User{id: owner_id}, id) do
    Repo.get_by(Contact, id: id, owner_id: owner_id)
  end

  def create_contact(%User{id: owner_id}, attrs) do
    %Contact{owner_id: owner_id}
    |> Contact.changeset(attrs)
    |> Repo.insert()
  end

  def update_contact(%User{} = owner, id, attrs) do
    with %Contact{} = contact <- get_contact(owner, id) do
      contact
      |> Contact.changeset(attrs)
      |> Repo.update()
    end
  end

  def delete_contact(%User{} = owner, id) do
    with %Contact{} = contact <- get_contact(owner, id) do
      Repo.delete(contact)
    end
  end

  defp preload_matome_contacts({:ok, %Matome{} = matome}),
    do: {:ok, Repo.preload(matome, :matome_contacts)}

  defp preload_matome_contacts(result), do: result

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

  defp validate_matome_owner(changeset, owner) do
    matome_id = Changeset.get_field(changeset, :matome_id)

    cond do
      is_nil(matome_id) -> changeset
      get_matome(owner, matome_id) -> changeset
      true -> Changeset.add_error(changeset, :matome_id, "is invalid")
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
