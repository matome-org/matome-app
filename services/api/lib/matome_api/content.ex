defmodule MatomeApi.Content do
  import Ecto.Query

  alias Ecto.Changeset
  alias MatomeApi.Auth.User

  alias MatomeApi.Content.{
    Contact,
    FileBlob,
    Item,
    Matome,
    MatomeContact,
    SpaceKeyWrap,
    SpaceMember,
    TextContent,
    UploadLifecycle,
    Workspace
  }

  alias MatomeApi.AIEngine.DispatchJob
  alias MatomeApi.Events
  alias MatomeApi.Repo
  alias MatomeApi.Storage.{ObjectStore, Presigner, UploadPolicy}
  alias MatomeApi.SystemConfig

  @ai_media_types ~w(audio image document)

  def list_workspaces(%User{id: owner_id}, params \\ %{}) do
    member_ids =
      from(m in SpaceMember,
        where: m.user_id == ^owner_id and is_nil(m.revoked_at),
        select: m.workspace_id
      )

    Workspace
    |> where([w], w.owner_id == ^owner_id or w.id in subquery(member_ids))
    |> where([w], w.status != "deleted")
    |> search_by(:name, params["q"] || params[:q])
    |> order_by([workspace], asc: workspace.name)
    |> Repo.all()
  end

  def get_workspace(%User{id: user_id}, id) do
    case Repo.get(Workspace, id) do
      nil ->
        nil

      %Workspace{status: "deleted"} ->
        nil

      %Workspace{owner_id: ^user_id} = workspace ->
        workspace

      %Workspace{} = workspace ->
        if space_member?(%User{id: user_id}, workspace.id), do: workspace, else: nil
    end
  end

  def create_workspace(%User{id: owner_id}, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:workspace, Workspace.changeset(%Workspace{owner_id: owner_id}, attrs))
    |> Ecto.Multi.insert(:owner_member, fn %{workspace: workspace} ->
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      SpaceMember.changeset(%SpaceMember{}, %{
        workspace_id: workspace.id,
        user_id: owner_id,
        role: "owner",
        granted_at: now
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{workspace: workspace}} -> {:ok, workspace}
      {:error, :workspace, changeset, _} -> {:error, changeset}
      {:error, _step, reason, _} -> {:error, reason}
    end
  end

  @doc "True when user owns the space or has an active membership row."
  def space_member?(%User{id: user_id}, workspace_id) do
    from(m in SpaceMember,
      where: m.workspace_id == ^workspace_id,
      where: m.user_id == ^user_id,
      where: is_nil(m.revoked_at)
    )
    |> Repo.exists?()
  end

  def space_role(%User{id: user_id}, workspace_id) do
    case Repo.get(Workspace, workspace_id) do
      %Workspace{owner_id: ^user_id} ->
        "owner"

      _ ->
        from(m in SpaceMember,
          where: m.workspace_id == ^workspace_id,
          where: m.user_id == ^user_id,
          where: is_nil(m.revoked_at),
          select: m.role,
          limit: 1
        )
        |> Repo.one()
    end
  end

  def can_manage_members?(%User{} = user, workspace_id) do
    space_role(user, workspace_id) in ~w(owner admin)
  end

  def can_share_keys?(%User{} = user, workspace_id) do
    space_role(user, workspace_id) in ~w(owner admin member)
  end

  ## Space key wraps (ADR-0003) — opaque blobs only

  def get_own_space_key_wrap(%User{id: user_id} = user, workspace_id) do
    with %Workspace{} <- get_workspace(user, workspace_id) do
      from(w in SpaceKeyWrap,
        where: w.workspace_id == ^workspace_id,
        where: w.user_id == ^user_id,
        where: is_nil(w.revoked_at)
      )
      |> Repo.one()
    end
  end

  def put_space_key_wrap(%User{} = sharer, workspace_id, recipient_id, attrs) do
    with true <- can_share_keys?(sharer, workspace_id) || {:error, :forbidden},
         true <- space_member?(%User{id: recipient_id}, workspace_id) || {:error, :not_a_member} do
      attrs =
        Map.merge(attrs, %{
          "workspace_id" => workspace_id,
          "user_id" => recipient_id,
          "created_by_id" => sharer.id,
          "alg_id" => Map.get(attrs, "alg_id") || Map.get(attrs, :alg_id) || 1,
          "revoked_at" => nil
        })

      case Repo.get_by(SpaceKeyWrap, workspace_id: workspace_id, user_id: recipient_id) do
        nil ->
          %SpaceKeyWrap{}
          |> SpaceKeyWrap.changeset(attrs)
          |> Repo.insert()

        existing ->
          existing
          |> SpaceKeyWrap.changeset(Map.put(attrs, "revoked_at", nil))
          |> Repo.update()
      end
    else
      false -> {:error, :forbidden}
      {:error, reason} -> {:error, reason}
    end
  end

  def revoke_space_key_wrap(%User{} = actor, workspace_id, recipient_id) do
    with true <- can_manage_members?(actor, workspace_id) || {:error, :forbidden},
         %SpaceKeyWrap{} = wrap <-
           Repo.get_by(SpaceKeyWrap, workspace_id: workspace_id, user_id: recipient_id) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      wrap
      |> Ecto.Changeset.change(revoked_at: now)
      |> Repo.update()
    else
      nil -> nil
      false -> {:error, :forbidden}
      {:error, reason} -> {:error, reason}
    end
  end

  def list_pending_key_shares(%User{} = actor, workspace_id) do
    with true <- can_share_keys?(actor, workspace_id) || {:error, :forbidden},
         %Workspace{} = workspace <- Repo.get(Workspace, workspace_id) do
      wrapped_ids =
        from(w in SpaceKeyWrap,
          where: w.workspace_id == ^workspace_id and is_nil(w.revoked_at),
          select: w.user_id
        )

      # Owner holds Space-DEK via personal unlock — no wrap row required.
      from(m in SpaceMember,
        where: m.workspace_id == ^workspace_id,
        where: is_nil(m.revoked_at),
        where: m.user_id != ^workspace.owner_id,
        where: m.user_id not in subquery(wrapped_ids),
        preload: [:user]
      )
      |> Repo.all()
      |> then(&{:ok, &1})
    else
      nil -> {:error, :not_found}
      false -> {:error, :forbidden}
      {:error, reason} -> {:error, reason}
    end
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
      matome = Repo.preload(matome, :workspace)

      {result, storage_keys} =
        Ecto.Multi.new()
        |> Ecto.Multi.run(:payloads, fn repo, _changes ->
          delete_matome_payloads(repo, matome)
        end)
        |> Ecto.Multi.delete(:matome, matome)
        |> Repo.transaction()
        |> case do
          {:ok, %{matome: matome, payloads: storage_keys}} -> {{:ok, matome}, storage_keys}
          {:error, _step, reason, _changes} -> {{:error, reason}, []}
        end

      delete_storage_objects(storage_keys)
      result
    end
  end

  ## Items

  def list_items(%User{id: owner_id}) do
    Item
    |> where([item], item.owner_id == ^owner_id)
    |> order_by([item], desc: item.inserted_at)
    |> Repo.all()
    |> Repo.preload([:workspace, :matome, :file_blob, :text_content])
  end

  def list_items(%User{} = owner, matome_id) do
    with %Matome{} = matome <- get_matome(owner, matome_id) do
      Item
      |> where([item], item.matome_id == ^matome.id)
      |> order_by([item], asc: item.position)
      |> Repo.all()
      |> Repo.preload([:workspace, :matome, :file_blob, :text_content])
    end
  end

  def get_item(%User{id: owner_id}, id) do
    Item
    |> where([item], item.id == ^id and item.owner_id == ^owner_id)
    |> Repo.one()
    |> case do
      nil -> nil
      item -> Repo.preload(item, [:workspace, :matome, :file_blob, :text_content])
    end
  end

  def create_text_item(%User{} = owner, matome_id, attrs) do
    with {:ok, placement} <- resolve_item_placement(owner, matome_id, attrs) do
      client_id = item_client_id(attrs)
      fingerprint = item_create_fingerprint(:text, placement, attrs, client_id)

      idempotent_item_create(owner, client_id, fingerprint, fn ->
        Ecto.Multi.new()
        |> Ecto.Multi.insert(:text_content, TextContent.changeset(%TextContent{}, attrs))
        |> Ecto.Multi.run(:position, fn repo, _changes ->
          next_item_position(repo, placement.matome_id, attrs)
        end)
        |> Ecto.Multi.insert(:item, fn %{text_content: text_content, position: position} ->
          item_attrs = %{
            owner_id: owner.id,
            client_id: client_id,
            client_fingerprint: fingerprint,
            workspace_id: placement.workspace_id,
            matome_id: placement.matome_id,
            position: position,
            item_type: :text,
            title: item_title(attrs),
            notes: item_attr(attrs, :notes),
            metadata: Map.get(attrs, :metadata) || Map.get(attrs, "metadata") || %{},
            text_content_id: text_content.id
          }

          Item.changeset(%Item{}, item_attrs)
        end)
        |> Repo.transaction()
        |> case do
          {:ok, %{item: item}} ->
            {:ok, Repo.preload(item, [:workspace, :matome, :file_blob, :text_content])}

          {:error, _step, changeset, _changes} ->
            {:error, changeset}
        end
      end)
    else
      {:error, :not_found} -> nil
    end
  end

  def create_file_item(%User{} = owner, matome_id, attrs) do
    with {:ok, placement} <- resolve_item_placement(owner, matome_id, attrs) do
      attrs =
        attrs
        |> put_byte_size_from_content_length()
        |> drop_server_file_state()
        |> put_storage_key(storage_key(owner.id))

      incoming = incoming_byte_size(attrs)
      client_id = item_client_id(attrs)
      fingerprint = item_create_fingerprint(:file, placement, attrs, client_id)

      idempotent_item_create(owner, client_id, fingerprint, fn ->
        Ecto.Multi.new()
        |> Ecto.Multi.run(:quota, fn repo, _changes ->
          reserve_workspace_quota(repo, placement.effective_workspace_id, incoming)
        end)
        |> Ecto.Multi.insert(:file_blob, FileBlob.changeset(%FileBlob{}, attrs))
        |> Ecto.Multi.run(:position, fn repo, _changes ->
          next_item_position(repo, placement.matome_id, attrs)
        end)
        |> Ecto.Multi.insert(:item, fn %{file_blob: file_blob, position: position} ->
          item_attrs = %{
            owner_id: owner.id,
            client_id: client_id,
            client_fingerprint: fingerprint,
            workspace_id: placement.workspace_id,
            matome_id: placement.matome_id,
            position: position,
            item_type: :file,
            title: item_title(attrs),
            notes: item_attr(attrs, :notes),
            metadata: item_metadata(attrs),
            file_blob_id: file_blob.id
          }

          Item.changeset(%Item{}, item_attrs)
        end)
        |> Repo.transaction()
        |> case do
          {:ok, %{item: item}} ->
            {:ok, Repo.preload(item, [:workspace, :matome, :file_blob, :text_content])}

          {:error, :quota, reason, _changes} when is_atom(reason) ->
            {:error, reason}

          {:error, _step, changeset, _changes} ->
            {:error, changeset}
        end
      end)
    else
      {:error, :not_found} -> nil
    end
  end

  def presign_item_upload(%User{} = owner, id, attrs \\ %{}) do
    with %Item{} = item <- get_item(owner, id),
         %Item{item_type: :file, file_blob: %FileBlob{} = file_blob} <- item do
      byte_size = Map.get(attrs, "byte_size") || Map.get(attrs, :byte_size) || file_blob.byte_size

      with :ok <- UploadPolicy.validate_size(file_blob.media_type, byte_size),
           true <- byte_size == file_blob.byte_size || {:error, :declared_size_mismatch},
           true <-
             UploadPolicy.mode_for(file_blob.media_type, byte_size) == :single ||
               {:error, :multipart_required} do
        Presigner.presign_upload(file_blob.storage_key, content_length: byte_size)
      end
    else
      %Item{item_type: :text} -> {:error, :text_item_not_presignable}
      nil -> nil
      {:error, reason} -> {:error, reason}
    end
  end

  def request_item_upload(%User{} = owner, id, attrs \\ %{}),
    do: UploadLifecycle.request(owner, id, attrs)

  def inspect_item_upload(%User{} = owner, upload_id),
    do: UploadLifecycle.inspect(owner, upload_id)

  def presign_item_upload_part(%User{} = owner, upload_id, part_number, attrs),
    do: UploadLifecycle.presign_part(owner, upload_id, part_number, attrs)

  def complete_item_upload(%User{} = owner, upload_id, attrs),
    do: UploadLifecycle.complete(owner, upload_id, attrs)

  def abort_item_upload(%User{} = owner, upload_id, attrs \\ %{}),
    do: UploadLifecycle.abort(owner, upload_id, attrs)

  def presign_item_download(%User{} = owner, id) do
    with %Item{} = item <- get_item(owner, id),
         %Item{item_type: :file, file_blob: %FileBlob{} = file_blob} <- item do
      Presigner.presign_download(file_blob.storage_key)
    else
      %Item{item_type: :text} -> {:error, :text_item_not_downloadable}
      nil -> nil
      {:error, reason} -> {:error, reason}
    end
  end

  def update_item(%User{} = owner, id, attrs) do
    with %Item{} = item <- get_item(owner, id) do
      Repo.transaction(fn ->
        with {:ok, patch} <- item_update_attrs(owner, item, attrs),
             {:ok, _updated} <- item |> Item.changeset(patch) |> Repo.update() do
          get_item(owner, id)
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
      |> case do
        {:ok, updated} -> {:ok, updated}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def enqueue_item_processing(%User{} = owner, id) do
    config = SystemConfig.snapshot()

    with %Item{item_type: :file, file_blob: %FileBlob{} = file_blob} = item <-
           get_item(owner, id),
         true <-
           file_blob.media_type in @ai_media_types and
             file_blob.media_type in config["desired"]["ai"]["enabled_input_kinds"],
         true <- file_blob.upload_state == "uploaded" || {:error, :upload_not_complete} do
      result = queue_item_processing(item, file_blob, config)

      if match?({:ok, _item}, result) and item.processing_state == :not_requested do
        Events.write_optional("operational.upload_completed.v1", %{
          actor_id: owner.id,
          owner_id: owner.id,
          subject_type: "item",
          subject_id: to_string(item.id),
          details: %{
            mode: "single",
            byte_size: file_blob.byte_size,
            part_count: 1,
            result: "ok"
          }
        })
      end

      result
    else
      %Item{item_type: :text} -> {:error, :text_item_not_processable}
      false -> {:error, :unsupported_media_type}
      {:error, reason} -> {:error, reason}
      nil -> nil
    end
  end

  def update_file_item_result(item_id, file_blob_id, attrs) do
    with %Item{item_type: :file, file_blob: %FileBlob{id: ^file_blob_id} = file_blob} = item <-
           Item
           |> where([item], item.id == ^item_id and item.file_blob_id == ^file_blob_id)
           |> Repo.one()
           |> Repo.preload(:file_blob) do
      outputs = processing_outputs(attrs)

      result =
        item
        |> Item.processing_changeset(%{
          processing_state: :succeeded,
          processing_outputs: outputs,
          processing_error: nil
        })
        |> Repo.update()

      if match?({:ok, _item}, result) and item.processing_state != :succeeded do
        Events.write_optional("operational.processing_completed.v1", %{
          owner_id: item.owner_id,
          subject_type: "item",
          subject_id: to_string(item.id),
          run_id: item.processing_run_id,
          details: %{
            input_kind: file_blob.media_type,
            output_types: outputs |> Map.keys() |> Enum.sort(),
            result: "ok"
          }
        })
      end

      result
    else
      nil -> nil
    end
  end

  def ai_dispatch_payload(item_id, file_blob_id) do
    with %Item{item_type: :file, file_blob: %FileBlob{id: ^file_blob_id} = file_blob} = item <-
           Item
           |> where([item], item.id == ^item_id and item.file_blob_id == ^file_blob_id)
           |> Repo.one()
           |> Repo.preload(:file_blob),
         true <- file_blob.upload_state == "uploaded",
         {:ok, media} <- Presigner.presign_download(file_blob.storage_key),
         {:ok, item} <-
           item
           |> Item.processing_changeset(%{processing_state: :processing})
           |> Repo.update() do
      job_id = item_job_id(item.id, file_blob.id)

      {:ok,
       %{
         job_id: job_id,
         recording_id: item.id,
         item_id: item.id,
         file_blob_id: file_blob.id,
         media_type: file_blob.media_type,
         storage_key: file_blob.storage_key,
         media: %{method: "GET", url: media.url},
         callback: %{
           method: "POST",
           url: "#{MatomeApi.AIEngine.callback_base_url()}/internal/jobs/#{job_id}/result"
         }
       }}
    else
      nil -> {:discard, :missing_item}
      false -> {:discard, :upload_not_complete}
      {:error, reason} -> {:error, reason}
    end
  end

  def item_job_id(item_id, file_blob_id), do: "item:#{item_id}:file_blob:#{file_blob_id}"

  def persisted_ai_dispatch?(item_id, file_blob_id) do
    Oban.Job
    |> where([job], fragment("?->>'item_id' = ?", job.args, ^to_string(item_id)))
    |> where([job], fragment("?->>'file_blob_id' = ?", job.args, ^to_string(file_blob_id)))
    |> Repo.exists?()
  end

  def delete_item(%User{} = owner, id) do
    with %Item{} = item <- get_item(owner, id) do
      {result, storage_keys} = delete_item_transaction(item)
      delete_storage_objects(storage_keys)
      result
    end
  end

  defp delete_item_transaction(item) do
    item = Repo.preload(item, [:file_blob, matome: :workspace])

    Ecto.Multi.new()
    |> Ecto.Multi.run(:release_quota, fn repo, _changes ->
      release_workspace_quota(repo, item)
    end)
    |> Ecto.Multi.delete(:item, item)
    |> Ecto.Multi.run(:payload, fn repo, _changes -> delete_item_payload(repo, item) end)
    |> Repo.transaction()
    |> case do
      {:ok, %{item: item, payload: storage_keys}} -> {{:ok, item}, List.wrap(storage_keys)}
      {:error, _step, reason, _changes} -> {{:error, reason}, []}
    end
  rescue
    error in [Ecto.ConstraintError, Ecto.StaleEntryError] -> {{:error, error}, []}
  end

  @doc """
  Reserve ciphertext bytes against a workspace quota.

  Locks the workspace row (`FOR UPDATE`) so concurrent under-quota uploads that
  would sum over the ceiling serialize — one succeeds, the other gets
  `:quota_exceeded`. `nil` workspace_id skips enforcement (loose / unfiled).
  """
  def reserve_workspace_quota(_repo, nil, _incoming), do: {:ok, :no_workspace}

  def reserve_workspace_quota(repo, workspace_id, incoming) when is_integer(incoming) do
    workspace =
      Workspace
      |> where([w], w.id == ^workspace_id)
      |> lock("FOR UPDATE")
      |> then(&repo.one/1)

    cond do
      is_nil(workspace) ->
        {:error, :workspace_not_found}

      not Workspace.writable?(workspace) ->
        {:error, :space_not_writable}

      is_nil(workspace.quota_bytes) ->
        {:ok, workspace}

      workspace.used_bytes + incoming > workspace.quota_bytes ->
        {:error, :quota_exceeded}

      true ->
        workspace
        |> Ecto.Changeset.change(used_bytes: workspace.used_bytes + incoming)
        |> then(&repo.update/1)
    end
  end

  def reserve_workspace_quota(_repo, _workspace_id, _incoming), do: {:error, :invalid_byte_size}

  defp release_workspace_quota(_repo, %Item{item_type: :text}), do: {:ok, :text}

  defp release_workspace_quota(repo, %Item{
         item_type: :file,
         file_blob: %FileBlob{byte_size: byte_size},
         matome: matome,
         workspace_id: direct_workspace_id
       })
       when is_integer(byte_size) and byte_size > 0 do
    workspace_id = if matome, do: matome.workspace_id, else: direct_workspace_id

    release_workspace_quota(repo, workspace_id, byte_size)
  end

  defp release_workspace_quota(_repo, _item), do: {:ok, :noop}

  defp release_workspace_quota(repo, workspace_id, byte_size) when is_integer(workspace_id) do
    workspace =
      Workspace
      |> where([w], w.id == ^workspace_id)
      |> lock("FOR UPDATE")
      |> then(&repo.one/1)

    case workspace do
      nil ->
        {:ok, :missing}

      %Workspace{} = workspace ->
        next = max(workspace.used_bytes - byte_size, 0)

        workspace
        |> Ecto.Changeset.change(used_bytes: next)
        |> then(&repo.update/1)
    end
  end

  defp release_workspace_quota(_repo, _workspace_id, _byte_size), do: {:ok, :noop}

  defp incoming_byte_size(attrs) do
    case Map.get(attrs, :byte_size) || Map.get(attrs, "byte_size") do
      size when is_integer(size) -> size
      size when is_binary(size) -> String.to_integer(size)
      _ -> 0
    end
  rescue
    ArgumentError -> 0
  end

  @doc """
  Reap payload rows (and their private storage objects) that no `item`
  references. App-level deletes (`delete_matome`/`delete_item`) already clean up
  their own payloads, but a cascade that bypasses them — e.g. a future
  account/user deletion that drops matomes with `on_delete: :delete_all` — would
  strand the `restrict`-scoped `file_blobs`/`text_contents` rows and leave their
  storage objects orphaned. This sweep detects and removes those orphans.

  Returns `{:ok, %{file_blob_ids: [...], text_content_ids: [...], storage_keys: [...]}}`.
  """
  def sweep_orphaned_payloads do
    orphan_blobs =
      FileBlob
      |> join(:left, [blob], item in Item, on: item.file_blob_id == blob.id)
      |> where([blob, item], is_nil(item.id))
      |> select([blob], {blob.id, blob.storage_key})
      |> Repo.all()

    blob_ids = Enum.map(orphan_blobs, &elem(&1, 0))
    storage_keys = orphan_blobs |> Enum.map(&elem(&1, 1)) |> Enum.reject(&is_nil/1)

    orphan_text_ids =
      TextContent
      |> join(:left, [text], item in Item, on: item.text_content_id == text.id)
      |> where([text, item], is_nil(item.id))
      |> select([text], text.id)
      |> Repo.all()

    Repo.delete_all(from(blob in FileBlob, where: blob.id in ^blob_ids))
    Repo.delete_all(from(text in TextContent, where: text.id in ^orphan_text_ids))

    delete_storage_objects(storage_keys)

    {:ok,
     %{
       file_blob_ids: blob_ids,
       text_content_ids: orphan_text_ids,
       storage_keys: storage_keys
     }}
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

  defp delete_item_payload(repo, %Item{item_type: :file, file_blob_id: file_blob_id}) do
    file_blob_id
    |> then(&repo.get(FileBlob, &1))
    |> case do
      nil ->
        {:ok, nil}

      file_blob ->
        {:ok, _file_blob} = repo.delete(file_blob)
        {:ok, file_blob.storage_key}
    end
  end

  defp delete_item_payload(repo, %Item{item_type: :text, text_content_id: text_content_id}) do
    text_content_id
    |> then(&repo.get(TextContent, &1))
    |> case do
      nil -> {:ok, nil}
      text_content -> repo.delete(text_content)
    end
  end

  defp delete_matome_payloads(repo, %Matome{} = matome) do
    items =
      Item
      |> where([item], item.matome_id == ^matome.id)
      |> preload([:file_blob])
      |> repo.all()

    if matome.workspace_id do
      total =
        items
        |> Enum.filter(&(&1.item_type == :file && &1.file_blob))
        |> Enum.reduce(0, fn item, acc -> acc + (item.file_blob.byte_size || 0) end)

      if total > 0 do
        workspace =
          Workspace
          |> where([w], w.id == ^matome.workspace_id)
          |> lock("FOR UPDATE")
          |> then(&repo.one/1)

        if workspace do
          next = max(workspace.used_bytes - total, 0)

          {:ok, _} =
            workspace
            |> Ecto.Changeset.change(used_bytes: next)
            |> then(&repo.update/1)
        end
      end
    end

    repo.delete_all(from(item in Item, where: item.matome_id == ^matome.id))

    storage_keys =
      Enum.flat_map(items, fn item ->
        case delete_item_payload(repo, item) do
          {:ok, nil} -> []
          {:ok, %TextContent{}} -> []
          {:ok, storage_key} when is_binary(storage_key) -> [storage_key]
        end
      end)

    {:ok, storage_keys}
  end

  defp delete_storage_objects(storage_keys) do
    Enum.each(storage_keys, &ObjectStore.delete_object/1)
  end

  defp idempotent_item_create(_owner, nil, _fingerprint, create), do: create.()

  defp idempotent_item_create(%User{} = owner, client_id, fingerprint, create) do
    case get_item_by_client_id(owner, client_id) do
      nil ->
        case create.() do
          {:error, _reason} = error ->
            case get_item_by_client_id(owner, client_id) do
              nil -> error
              item -> replay_item(item, fingerprint)
            end

          result ->
            result
        end

      item ->
        replay_item(item, fingerprint)
    end
  end

  defp get_item_by_client_id(%User{id: owner_id}, client_id) do
    Item
    |> where([item], item.owner_id == ^owner_id and item.client_id == ^client_id)
    |> Repo.one()
    |> case do
      nil -> nil
      item -> Repo.preload(item, [:workspace, :matome, :file_blob, :text_content])
    end
  end

  defp replay_item(%Item{client_fingerprint: fingerprint} = item, fingerprint),
    do: {:ok, item}

  defp replay_item(%Item{}, _fingerprint), do: {:error, :client_id_conflict}

  defp resolve_item_placement(%User{} = owner, matome_id, attrs) do
    with {:ok, matome} <- resolve_item_matome(owner, matome_id),
         {:ok, workspace_id} <- resolve_direct_workspace(owner, attrs) do
      {:ok,
       %{
         matome_id: matome && matome.id,
         workspace_id: workspace_id,
         effective_workspace_id: if(matome, do: matome.workspace_id, else: workspace_id)
       }}
    end
  end

  defp resolve_item_matome(_owner, nil), do: {:ok, nil}

  defp resolve_item_matome(owner, matome_id) do
    case get_matome(owner, matome_id) do
      %Matome{} = matome -> {:ok, matome}
      nil -> {:error, :not_found}
    end
  end

  defp resolve_direct_workspace(%User{id: owner_id}, attrs) do
    case fetch_item_attr(attrs, :workspace_id) do
      :error ->
        {:ok, nil}

      {:ok, nil} ->
        {:ok, nil}

      {:ok, workspace_id} ->
        case Repo.get_by(Workspace, id: workspace_id, owner_id: owner_id) do
          %Workspace{} -> {:ok, workspace_id}
          nil -> {:error, :not_found}
        end
    end
  end

  defp item_update_attrs(owner, item, attrs) do
    patch =
      [:title, :notes]
      |> Enum.reduce(%{}, fn key, acc ->
        case fetch_item_attr(attrs, key) do
          {:ok, value} -> Map.put(acc, key, value)
          :error -> acc
        end
      end)
      |> maybe_merge_metadata(item, attrs)

    with {:ok, patch} <- put_matome_update(patch, owner, item, attrs),
         {:ok, patch} <- put_workspace_update(patch, owner, attrs) do
      {:ok, patch}
    end
  end

  defp maybe_merge_metadata(patch, item, attrs) do
    case fetch_item_attr(attrs, :metadata) do
      {:ok, metadata} when is_map(metadata) ->
        Map.put(patch, :metadata, Map.merge(item.metadata || %{}, metadata))

      _ ->
        patch
    end
  end

  defp put_matome_update(patch, owner, item, attrs) do
    case fetch_item_attr(attrs, :matome_id) do
      :error ->
        {:ok, patch}

      {:ok, nil} ->
        {:ok, Map.merge(patch, %{matome_id: nil, position: nil})}

      {:ok, matome_id} when matome_id == item.matome_id ->
        {:ok, patch}

      {:ok, matome_id} ->
        case get_matome(owner, matome_id) do
          %Matome{} ->
            {:ok, position} = next_item_position(Repo, matome_id, %{})
            {:ok, Map.merge(patch, %{matome_id: matome_id, position: position})}

          nil ->
            {:error, :not_found}
        end
    end
  end

  defp put_workspace_update(patch, %User{id: owner_id}, attrs) do
    case fetch_item_attr(attrs, :workspace_id) do
      :error ->
        {:ok, patch}

      {:ok, nil} ->
        {:ok, Map.put(patch, :workspace_id, nil)}

      {:ok, workspace_id} ->
        case Repo.get_by(Workspace, id: workspace_id, owner_id: owner_id) do
          %Workspace{} -> {:ok, Map.put(patch, :workspace_id, workspace_id)}
          nil -> {:error, :not_found}
        end
    end
  end

  defp queue_item_processing(item, file_blob, config) do
    config_revision = config["revision"]
    retry_policy = config["desired"]["retry"]
    processing_policy = config["desired"]["ai"]

    Repo.transaction(fn ->
      with {:ok, item} <- mark_item_processing_queued(item, config_revision),
           {:ok, _job} <-
             %{
               item_id: item.id,
               file_blob_id: file_blob.id,
               config_revision: config_revision,
               retry: retry_policy,
               processing: processing_policy
             }
             |> DispatchJob.new(queue: :ai, max_attempts: retry_policy["max_attempts"])
             |> Oban.insert() do
        Repo.preload(item, [:workspace, :matome, :file_blob, :text_content], force: true)
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, item} -> {:ok, item}
      {:error, reason} -> {:error, reason}
    end
  end

  defp mark_item_processing_queued(
         %Item{processing_state: :not_requested} = item,
         config_revision
       ) do
    item
    |> Item.processing_changeset(%{
      processing_state: :queued,
      processing_run_id: Ecto.UUID.generate(),
      processing_config_revision: config_revision,
      processing_outputs: %{},
      processing_error: nil
    })
    |> Repo.update()
  end

  defp mark_item_processing_queued(%Item{processing_state: :failed} = item, config_revision) do
    item
    |> Item.processing_changeset(%{
      processing_state: :queued,
      processing_config_revision: config_revision,
      processing_outputs: %{},
      processing_error: nil
    })
    |> Repo.update()
  end

  defp mark_item_processing_queued(%Item{} = item, _config_revision), do: {:ok, item}

  defp processing_outputs(attrs) do
    %{}
    |> maybe_put_output(
      "transcript",
      Map.get(attrs, "transcript") || Map.get(attrs, :transcript),
      "text"
    )
    |> maybe_put_output(
      "summary",
      Map.get(attrs, "summary") || Map.get(attrs, :summary),
      "markdown"
    )
  end

  defp maybe_put_output(outputs, _type, nil, _value_key), do: outputs

  defp maybe_put_output(outputs, type, value, value_key) do
    Map.put(outputs, type, %{"type" => type, value_key => value})
  end

  defp item_client_id(attrs), do: item_attr(attrs, :client_id)

  defp item_create_fingerprint(_type, _placement, _attrs, nil), do: nil

  defp item_create_fingerprint(:text, placement, attrs, _client_id) do
    {
      :text,
      placement.matome_id,
      placement.workspace_id,
      item_attr(attrs, :position),
      item_title(attrs),
      item_attr(attrs, :notes),
      item_attr(attrs, :body),
      item_attr(attrs, :metadata) || %{}
    }
    |> fingerprint()
  end

  defp item_create_fingerprint(:file, placement, attrs, _client_id) do
    {
      :file,
      placement.matome_id,
      placement.workspace_id,
      item_attr(attrs, :position),
      item_title(attrs),
      item_attr(attrs, :notes),
      item_attr(attrs, :media_type),
      item_attr(attrs, :filename),
      item_attr(attrs, :content_type),
      incoming_byte_size(attrs),
      item_attr(attrs, :checksum_sha256),
      item_attr(attrs, :duration),
      item_metadata(attrs)
    }
    |> fingerprint()
  end

  defp fingerprint(value) do
    value
    |> canonical_term()
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp canonical_term(value) when is_map(value) do
    value
    |> Enum.map(fn {key, nested} -> {to_string(key), canonical_term(nested)} end)
    |> Enum.sort()
  end

  defp canonical_term(value) when is_list(value), do: Enum.map(value, &canonical_term/1)

  defp canonical_term(value) when is_tuple(value),
    do: value |> Tuple.to_list() |> canonical_term()

  defp canonical_term(value), do: value

  defp fetch_item_attr(attrs, key) do
    cond do
      Map.has_key?(attrs, key) -> Map.fetch(attrs, key)
      Map.has_key?(attrs, Atom.to_string(key)) -> Map.fetch(attrs, Atom.to_string(key))
      true -> :error
    end
  end

  defp item_attr(attrs, key) do
    case fetch_item_attr(attrs, key) do
      {:ok, value} -> value
      :error -> nil
    end
  end

  defp item_title(attrs), do: item_attr(attrs, :title) || "Untitled"

  defp next_item_position(_repo, nil, _attrs), do: {:ok, nil}

  defp next_item_position(repo, matome_id, attrs) do
    case Map.get(attrs, :position) || Map.get(attrs, "position") do
      nil ->
        Matome
        |> where([matome], matome.id == ^matome_id)
        |> lock("FOR UPDATE")
        |> repo.one()

        position =
          Item
          |> where([item], item.matome_id == ^matome_id)
          |> select([item], coalesce(max(item.position), -1) + 1)
          |> repo.one()

        {:ok, position}

      position ->
        {:ok, position}
    end
  end

  defp item_metadata(attrs) do
    Map.get(attrs, :metadata) || Map.get(attrs, "metadata") || %{}
  end

  defp validate_workspace_owner(changeset, owner) do
    workspace_id = Changeset.get_field(changeset, :workspace_id)

    cond do
      is_nil(workspace_id) -> changeset
      get_workspace(owner, workspace_id) -> changeset
      true -> Changeset.add_error(changeset, :workspace_id, "is invalid")
    end
  end

  # Client uploaders (Flutter recordings_repository) send `content_length` — the
  # HTTP body size — while the FileBlob changeset requires `byte_size`. Map the
  # former onto the latter when byte_size was not supplied directly, preserving
  # the caller's key style (atom vs string). Without this every real file-item
  # create 422s with `byte_size can't be blank`.
  defp put_byte_size_from_content_length(attrs) do
    cond do
      Map.has_key?(attrs, :byte_size) or Map.has_key?(attrs, "byte_size") ->
        attrs

      Map.has_key?(attrs, :content_length) ->
        Map.put(attrs, :byte_size, Map.get(attrs, :content_length))

      Map.has_key?(attrs, "content_length") ->
        Map.put(attrs, "byte_size", Map.get(attrs, "content_length"))

      true ->
        attrs
    end
  end

  defp storage_key(owner_id) do
    "owners/#{owner_id}/items/#{Ecto.UUID.generate()}"
  end

  defp put_storage_key(attrs, storage_key) do
    attrs = attrs |> Map.delete(:storage_key) |> Map.delete("storage_key")

    if Enum.any?(Map.keys(attrs), &is_atom/1) do
      Map.put(attrs, :storage_key, storage_key)
    else
      Map.put(attrs, "storage_key", storage_key)
    end
  end

  defp drop_server_file_state(attrs) do
    Map.drop(attrs, [
      :upload_state,
      "upload_state",
      :upload_generation,
      "upload_generation",
      :uploaded_at,
      "uploaded_at",
      :multipart_context,
      "multipart_context"
    ])
  end

  defp maybe_filter_workspace(query, nil), do: query
  defp maybe_filter_workspace(query, ""), do: query

  defp maybe_filter_workspace(query, workspace_id),
    do: where(query, [row], row.workspace_id == ^workspace_id)

  defp search_by(query, _field, nil), do: query
  defp search_by(query, _field, ""), do: query

  defp search_by(query, field, term) do
    pattern = "%#{term}%"
    where(query, [row], ilike(field(row, ^field), ^pattern))
  end
end
