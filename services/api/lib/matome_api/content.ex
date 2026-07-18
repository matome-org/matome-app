defmodule MatomeApi.Content do
  import Ecto.Query

  alias Ecto.Changeset
  alias MatomeApi.Auth.User

  alias MatomeApi.Content.{
    Contact,
    DocumentOpenPolicy,
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

  alias MatomeApi.AIEngine
  alias MatomeApi.AIEngine.{Contract, DispatchJob, WatchdogJob}
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
    client_id = item_attr(attrs, :client_id)
    fingerprint = matome_create_fingerprint(attrs, client_id)

    idempotent_matome_create(owner, client_id, fingerprint, fn ->
      attrs =
        attrs
        |> put_file_attr(:client_fingerprint, fingerprint)

      %Matome{owner_id: owner.id}
      |> Matome.create_changeset(attrs)
      |> validate_workspace_owner(owner)
      |> Repo.insert()
      |> preload_matome_contacts()
    end)
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
    with {:ok, placement} <- resolve_item_placement(owner, matome_id, attrs),
         {:ok, attrs} <- prepare_file_attrs(attrs) do
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
      {:error, reason} -> {:error, reason}
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
      cond do
        file_blob.media_type == "document" and file_blob.upload_state != "uploaded" ->
          {:error, :file_not_uploaded}

        file_blob.media_type == "document" ->
          with :ok <- block_unsafe_document(file_blob),
               {:ok, descriptor} <- DocumentOpenPolicy.download_descriptor(file_blob),
               {:ok, file_blob} <- persist_document_policy(file_blob, descriptor.open_policy),
               {:ok, presign} <-
                 Presigner.presign_download(file_blob.storage_key,
                   expires_in: 300,
                   query: %{
                     "response-content-type" => descriptor.content_type,
                     "response-content-disposition" => descriptor.content_disposition,
                     "response-cache-control" => descriptor.cache_control
                   }
                 ) do
            {:ok,
             Map.merge(presign, %{
               filename: descriptor.filename,
               original_extension: descriptor.original_extension,
               content_type: descriptor.content_type,
               byte_size: file_blob.byte_size,
               open_policy: descriptor.open_policy,
               action: descriptor.action,
               warning: descriptor.warning
             })}
          end

        true ->
          Presigner.presign_download(file_blob.storage_key)
      end
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

  def update_text_item(%User{id: owner_id}, id, body, expected_source_revision)
      when is_binary(body) and is_integer(expected_source_revision) and
             expected_source_revision > 0 do
    Repo.transaction(fn ->
      item =
        Item
        |> where([item], item.id == ^id and item.owner_id == ^owner_id)
        |> lock("FOR UPDATE")
        |> Repo.one()

      case item do
        nil ->
          Repo.rollback(:not_found)

        %Item{item_type: item_type} when item_type != :text ->
          Repo.rollback(:item_type_mismatch)

        %Item{} = item ->
          text_content = Repo.get!(TextContent, item.text_content_id)

          cond do
            text_content.body == body and
                expected_source_revision in [item.source_revision, item.source_revision - 1] ->
              preload_item(item)

            expected_source_revision != item.source_revision ->
              Repo.rollback({:version_conflict, preload_item(item)})

            true ->
              with {:ok, _text_content} <-
                     text_content |> TextContent.changeset(%{body: body}) |> Repo.update(),
                   {:ok, revised} <-
                     item
                     |> Item.changeset(%{
                       source_revision: item.source_revision + 1,
                       processing_state: :not_requested,
                       processing_run_id: nil,
                       processing_attempt: 0,
                       processing_config_revision: nil,
                       processing_capabilities: nil,
                       processing_requested_outputs: [],
                       processing_requested_at: nil,
                       processing_deadline_at: nil,
                       processing_outputs: %{},
                       processing_error: nil
                     })
                     |> Repo.update() do
                preload_item(revised)
              else
                {:error, reason} -> Repo.rollback(reason)
              end
          end
      end
    end)
    |> case do
      {:ok, item} -> {:ok, item}
      {:error, :not_found} -> nil
      {:error, reason} -> {:error, reason}
    end
  end

  def delete_text_item(%User{id: owner_id}, id, expected_source_revision)
      when is_integer(expected_source_revision) and expected_source_revision > 0 do
    Repo.transaction(fn ->
      item =
        Item
        |> where([item], item.id == ^id and item.owner_id == ^owner_id)
        |> lock("FOR UPDATE")
        |> Repo.one()

      case item do
        nil ->
          Repo.rollback(:not_found)

        %Item{item_type: item_type} when item_type != :text ->
          Repo.rollback(:item_type_mismatch)

        %Item{source_revision: revision} = item when revision != expected_source_revision ->
          Repo.rollback({:version_conflict, preload_item(item)})

        %Item{} = item ->
          text_content = Repo.get!(TextContent, item.text_content_id)

          with {:ok, deleted} <- Repo.delete(item),
               {:ok, _payload} <- Repo.delete(text_content) do
            deleted
          else
            {:error, reason} -> Repo.rollback(reason)
          end
      end
    end)
    |> case do
      {:ok, item} -> {:ok, item}
      {:error, :not_found} -> nil
      {:error, reason} -> {:error, reason}
    end
  end

  def enqueue_item_processing(%User{} = owner, id) do
    config = SystemConfig.snapshot()

    case get_item(owner, id) do
      %Item{processing_state: state} = item when state in [:queued, :processing] ->
        {:ok, item}

      %Item{} = item ->
        request_item_processing(item, config)

      nil ->
        nil
    end
  end

  def ai_dispatch_payload(item_id, processing_run_id, source_revision) do
    with %Item{} = item <- processing_item(item_id, processing_run_id, source_revision),
         true <- item.processing_state in [:queued, :processing] || {:discard, :terminal_run},
         {:ok, input} <- dispatch_input(item),
         {:ok, item} <- mark_item_processing(item) do
      job_id = processing_job_id(item.processing_run_id)

      callback_identity =
        AIEngine.callback_identity(job_id, item.processing_run_id, item.source_revision)

      {:ok,
       %{
         contract_version: "1",
         job_id: job_id,
         run_id: item.processing_run_id,
         item_id: item.id,
         input_revision: item.source_revision,
         input: input,
         requested_outputs: item.processing_requested_outputs,
         callback: %{
           method: "POST",
           url: "#{AIEngine.callback_base_url()}/internal/v1/jobs/#{job_id}/result",
           deadline_at: DateTime.to_iso8601(item.processing_deadline_at),
           headers: %{authorization: "Bearer #{callback_identity}"}
         },
         metadata: processing_metadata(item)
       }}
    else
      nil -> {:discard, :missing_item}
      {:discard, reason} -> {:discard, reason}
      {:error, reason} -> {:error, reason}
    end
  end

  def processing_job_id(processing_run_id),
    do: "job_#{String.replace(processing_run_id, "-", "")}"

  def apply_processing_callback(route_job_id, attrs) do
    with %Oban.Job{} = job <- persisted_dispatch_job(route_job_id, attrs),
         requested_outputs when is_list(requested_outputs) <- job.args["requested_outputs"],
         {:ok, callback} <- Contract.normalize_callback(attrs, requested_outputs),
         true <- callback.job_id == route_job_id,
         true <- callback.item_id == job.args["item_id"] do
      apply_processing_terminal(callback, job.args["input_kind"])
    else
      nil -> {:error, :not_found}
      false -> {:error, :invalid_callback}
      {:error, reason} -> {:error, reason}
      _invalid -> {:error, :invalid_callback}
    end
  end

  def timeout_item_processing(
        item_id,
        processing_run_id,
        source_revision,
        now \\ DateTime.utc_now()
      ) do
    Repo.transaction(fn ->
      item = Item |> where([item], item.id == ^item_id) |> lock("FOR UPDATE") |> Repo.one()

      cond do
        is_nil(item) ->
          Repo.rollback(:not_found)

        item.processing_run_id != processing_run_id or item.source_revision != source_revision ->
          :stale

        item.processing_state not in [:queued, :processing] ->
          :stale

        DateTime.compare(item.processing_deadline_at, now) == :gt ->
          {:not_due, max(DateTime.diff(item.processing_deadline_at, now, :second), 1)}

        true ->
          error = %{
            "code" => "timeout",
            "message" => "Processing deadline exceeded.",
            "retryable" => true
          }

          from_state = item.processing_state

          with {:ok, item} <-
                 item
                 |> Item.processing_changeset(%{
                   processing_state: :failed,
                   processing_outputs: %{},
                   processing_error: error
                 })
                 |> Repo.update(),
               :ok <-
                 write_processing_terminal_events(
                   item,
                   from_state,
                   :failed,
                   [],
                   "timeout"
                 ) do
            :timed_out
          else
            {:error, reason} -> Repo.rollback(reason)
          end
      end
    end)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  def delete_item(%User{} = owner, id) do
    case get_item(owner, id) do
      nil ->
        nil

      %Item{item_type: :text} ->
        {:error, :text_endpoint_required}

      %Item{} = item ->
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

  defp preload_item(item),
    do: Repo.preload(item, [:workspace, :matome, :file_blob, :text_content], force: true)

  defp replay_item(%Item{client_fingerprint: fingerprint} = item, fingerprint),
    do: {:ok, item}

  defp replay_item(%Item{} = item, _fingerprint), do: {:error, {:client_id_conflict, item}}

  defp idempotent_matome_create(_owner, nil, _fingerprint, create), do: create.()

  defp idempotent_matome_create(%User{} = owner, client_id, fingerprint, create) do
    case get_matome_by_client_id(owner, client_id) do
      nil ->
        case create.() do
          {:error, _reason} = error ->
            case get_matome_by_client_id(owner, client_id) do
              nil -> error
              matome -> replay_matome(matome, fingerprint)
            end

          result ->
            result
        end

      matome ->
        replay_matome(matome, fingerprint)
    end
  end

  defp get_matome_by_client_id(%User{id: owner_id}, client_id) do
    Matome
    |> where([matome], matome.owner_id == ^owner_id and matome.client_id == ^client_id)
    |> Repo.one()
    |> case do
      nil -> nil
      matome -> Repo.preload(matome, :matome_contacts)
    end
  end

  defp replay_matome(%Matome{client_fingerprint: fingerprint} = matome, fingerprint),
    do: {:ok, matome}

  defp replay_matome(%Matome{}, _fingerprint), do: {:error, :client_id_conflict}

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

  defp request_item_processing(item, config) do
    with {:ok, source} <- processing_source(item, config) do
      case source do
        :not_requested ->
          {:ok, item}

        source ->
          case AIEngine.capabilities() do
            {:ok, capabilities} ->
              queue_item_processing(item, source, config, capabilities)

            {:error, _reason} ->
              {:error, :capabilities_unavailable}
          end
      end
    end
  end

  defp processing_source(%Item{item_type: :text, text_content: %TextContent{} = text}, config) do
    if "text" in config["desired"]["ai"]["enabled_input_kinds"] do
      {:ok, %{kind: "text", text_content: text}}
    else
      {:ok, :not_requested}
    end
  end

  defp processing_source(%Item{item_type: :file, file_blob: %FileBlob{} = file_blob}, config) do
    cond do
      file_blob.media_type not in @ai_media_types ->
        {:ok, :not_requested}

      file_blob.media_type not in config["desired"]["ai"]["enabled_input_kinds"] ->
        {:ok, :not_requested}

      file_blob.upload_state != "uploaded" ->
        {:error, :upload_not_complete}

      true ->
        {:ok, %{kind: file_blob.media_type, file_blob: file_blob}}
    end
  end

  defp queue_item_processing(item, source, config, capabilities) do
    config_revision = config["revision"]
    retry_policy = config["desired"]["retry"]
    processing_policy = config["desired"]["ai"]
    input_capability = capabilities["inputs"][source.kind]
    requested_outputs = Contract.requested_outputs(source.kind, input_capability)

    available? =
      requested_outputs != [] and capability_available?(source, input_capability, config)

    capabilities_snapshot = %{
      "contract_version" => capabilities["contract_version"],
      "service" => capabilities["service"],
      "input_kind" => source.kind,
      "input" => input_capability || %{"enabled" => false, "outputs" => []}
    }

    Repo.transaction(fn ->
      item =
        Item
        |> where([candidate], candidate.id == ^item.id)
        |> lock("FOR UPDATE")
        |> Repo.one!()

      with {:ok, item, created?, from_state} <-
             mark_item_processing_requested(
               item,
               capabilities_snapshot,
               requested_outputs,
               available?,
               config_revision,
               processing_policy
             ),
           :ok <- write_processing_requested_event(item, source.kind, created?, from_state),
           :ok <- write_upload_completed_event(item, source, created?, from_state),
           {:ok, _jobs} <-
             insert_processing_jobs(
               item,
               source,
               config_revision,
               retry_policy,
               processing_policy,
               config["desired"]["uploads"],
               created? and available?
             ) do
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

  defp mark_item_processing_requested(
         %Item{processing_state: state} = item,
         _capabilities_snapshot,
         _requested_outputs,
         _available?,
         _config_revision,
         _processing_policy
       )
       when state in [:queued, :processing],
       do: {:ok, item, false, state}

  defp mark_item_processing_requested(
         %Item{} = item,
         capabilities_snapshot,
         requested_outputs,
         available?,
         config_revision,
         processing_policy
       ) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    from_state = item.processing_state
    state = if available?, do: :queued, else: :not_available

    requested_outputs = if available?, do: requested_outputs, else: []

    item
    |> Item.processing_changeset(%{
      processing_state: state,
      processing_run_id: Ecto.UUID.generate(),
      processing_attempt: item.processing_attempt + 1,
      processing_config_revision: config_revision,
      processing_capabilities: capabilities_snapshot,
      processing_requested_outputs: requested_outputs,
      processing_requested_at: now,
      processing_deadline_at:
        DateTime.add(now, processing_policy["job_timeout_seconds"], :second),
      processing_outputs: %{},
      processing_error: nil
    })
    |> Repo.update()
    |> case do
      {:ok, item} -> {:ok, item, true, from_state}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp capability_available?(_source, nil, _config), do: false

  defp capability_available?(
         source,
         %{"enabled" => true, "outputs" => [_ | _]} = capability,
         config
       ) do
    case source do
      %{kind: "text", text_content: text} ->
        String.length(text.body) <= capability["max_characters"]

      %{file_blob: file_blob} ->
        file_blob.byte_size <=
          min(capability["max_bytes"], config["desired"]["uploads"]["max_bytes"]) and
          is_binary(file_blob.filename) and byte_size(file_blob.filename) in 1..1024 and
          file_blob.content_type in capability["content_types"] and
          is_binary(file_blob.checksum_sha256) and
          Regex.match?(~r/^[0-9a-f]{64}$/, file_blob.checksum_sha256)
    end
  end

  defp capability_available?(_source, _capability, _config), do: false

  defp insert_processing_jobs(
         _item,
         _source,
         _revision,
         _retry,
         _processing,
         _uploads,
         false
       ),
       do: {:ok, :not_available}

  defp insert_processing_jobs(
         item,
         source,
         config_revision,
         retry_policy,
         processing_policy,
         upload_policy,
         true
       ) do
    job_id = processing_job_id(item.processing_run_id)

    args = %{
      job_id: job_id,
      item_id: item.id,
      processing_run_id: item.processing_run_id,
      source_revision: item.source_revision,
      input_kind: source.kind,
      requested_outputs: item.processing_requested_outputs,
      config_revision: config_revision,
      system_config: %{
        revision: config_revision,
        ai: processing_policy,
        retry: retry_policy,
        uploads: upload_policy
      },
      retry: retry_policy,
      processing: processing_policy
    }

    with {:ok, dispatch} <-
           args
           |> DispatchJob.new(queue: :ai, max_attempts: retry_policy["max_attempts"])
           |> Oban.insert(),
         {:ok, watchdog} <-
           %{
             item_id: item.id,
             processing_run_id: item.processing_run_id,
             source_revision: item.source_revision
           }
           |> WatchdogJob.new(scheduled_at: item.processing_deadline_at)
           |> Oban.insert() do
      {:ok, %{dispatch: dispatch, watchdog: watchdog}}
    end
  end

  defp write_processing_requested_event(_item, _input_kind, false, _from_state), do: :ok

  defp write_processing_requested_event(item, input_kind, true, from_state) do
    write_processing_transition_event(item, input_kind, from_state, item.processing_state)
  end

  defp write_upload_completed_event(_item, _source, false, _from_state), do: :ok
  defp write_upload_completed_event(_item, %{kind: "text"}, true, _from_state), do: :ok

  defp write_upload_completed_event(_item, _source, true, from_state)
       when from_state != :not_requested,
       do: :ok

  defp write_upload_completed_event(item, %{file_blob: file_blob}, true, :not_requested) do
    case Events.write_optional("operational.upload_completed.v1", %{
           actor_id: item.owner_id,
           owner_id: item.owner_id,
           subject_type: "item",
           subject_id: to_string(item.id),
           details: %{
             mode: "single",
             byte_size: file_blob.byte_size,
             part_count: 1,
             result: "ok"
           }
         }) do
      {:ok, _event_or_disabled} -> :ok
      {:error, reason} -> {:error, {:event_insert_failed, reason}}
    end
  end

  defp processing_item(item_id, processing_run_id, source_revision) do
    case Repo.one(
           from(item in Item,
             where:
               item.id == ^item_id and item.processing_run_id == ^processing_run_id and
                 item.source_revision == ^source_revision
           )
         ) do
      nil -> nil
      item -> Repo.preload(item, [:file_blob, :text_content])
    end
  end

  defp dispatch_input(%Item{item_type: :text, text_content: %TextContent{} = text}),
    do: {:ok, %{kind: "text", body: text.body}}

  defp dispatch_input(%Item{
         item_type: :file,
         processing_run_id: processing_run_id,
         file_blob: %FileBlob{} = file_blob
       }) do
    with true <- file_blob.upload_state == "uploaded" || {:discard, :upload_not_complete},
         true <-
           (is_binary(file_blob.filename) and byte_size(file_blob.filename) in 1..1024) ||
             {:discard, :invalid_input_metadata},
         {:ok, media} <-
           Presigner.presign_download(file_blob.storage_key,
             server: true,
             query: %{
               "response-cache-control" =>
                 ~s(private, no-store, max-age=0, matome-run="#{processing_run_id}")
             }
           ) do
      {:ok,
       %{
         kind: file_blob.media_type,
         media: %{
           method: "GET",
           url: media.url,
           expires_at: DateTime.to_iso8601(media.expires_at),
           filename: file_blob.filename,
           content_type: file_blob.content_type,
           byte_size: file_blob.byte_size,
           checksum_sha256: file_blob.checksum_sha256
         }
       }}
    end
  end

  defp mark_item_processing(item) do
    Repo.transaction(fn ->
      current =
        Item
        |> where(
          [candidate],
          candidate.id == ^item.id and
            candidate.processing_run_id == ^item.processing_run_id and
            candidate.source_revision == ^item.source_revision
        )
        |> lock("FOR UPDATE")
        |> Repo.one()

      case current do
        %Item{processing_state: :queued} ->
          with {:ok, processing} <-
                 current
                 |> Item.processing_changeset(%{processing_state: :processing})
                 |> Repo.update(),
               :ok <-
                 write_processing_transition_event(
                   processing,
                   processing_input_kind(processing),
                   :queued,
                   :processing
                 ) do
            processing
          else
            {:error, reason} -> Repo.rollback(reason)
          end

        %Item{processing_state: :processing} ->
          current

        _terminal_or_missing ->
          Repo.rollback(:terminal_run)
      end
    end)
    |> case do
      {:ok, processing} -> {:ok, Repo.preload(processing, [:file_blob, :text_content])}
      {:error, :terminal_run} -> {:discard, :terminal_run}
      {:error, reason} -> {:error, reason}
    end
  end

  defp processing_metadata(item) do
    case item.metadata["language"] do
      locale when is_binary(locale) and byte_size(locale) <= 35 -> %{locale: locale}
      _no_locale -> %{}
    end
  end

  defp persisted_dispatch_job(route_job_id, attrs) do
    run_id = attrs["run_id"]
    source_revision = attrs["input_revision"]

    if is_binary(run_id) and is_integer(source_revision) do
      Oban.Job
      |> where([job], job.worker == "MatomeApi.AIEngine.DispatchJob")
      |> where([job], fragment("?->>'job_id' = ?", job.args, ^route_job_id))
      |> where([job], fragment("?->>'processing_run_id' = ?", job.args, ^run_id))
      |> where(
        [job],
        fragment("?->>'source_revision' = ?", job.args, ^to_string(source_revision))
      )
      |> Repo.one()
    end
  end

  defp apply_processing_terminal(callback, input_kind) do
    Repo.transaction(fn ->
      item =
        Item
        |> where([item], item.id == ^callback.item_id)
        |> lock("FOR UPDATE")
        |> Repo.one()

      cond do
        is_nil(item) ->
          Repo.rollback(:not_found)

        item.processing_run_id != callback.run_id or
            item.source_revision != callback.input_revision ->
          :stale

        item.processing_state == :queued ->
          Repo.rollback(:not_processing)

        item.processing_state == :processing and processing_input_kind(item) == input_kind ->
          from_state = :processing

          with {:ok, terminal} <-
                 item
                 |> Item.processing_changeset(%{
                   processing_state: callback.state,
                   processing_outputs: callback.outputs,
                   processing_error: callback.error
                 })
                 |> Repo.update(),
               :ok <-
                 write_processing_terminal_events(
                   terminal,
                   from_state,
                   callback.state,
                   Map.keys(callback.outputs),
                   terminal_result(callback.state)
                 ) do
            :applied
          else
            {:error, reason} -> Repo.rollback(reason)
          end

        item.processing_state == callback.state and
          item.processing_outputs == callback.outputs and
            item.processing_error == callback.error ->
          :duplicate

        true ->
          :stale
      end
    end)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  defp write_processing_terminal_events(item, from_state, to_state, output_types, result) do
    input_kind = processing_input_kind(item)

    with :ok <- write_processing_transition_event(item, input_kind, from_state, to_state),
         {:ok, _event_or_disabled} <-
           Events.write_optional("operational.processing_completed.v1", %{
             owner_id: item.owner_id,
             subject_type: "item",
             subject_id: to_string(item.id),
             run_id: item.processing_run_id,
             correlation_id: item.processing_run_id,
             details: %{
               input_kind: input_kind,
               output_types: Enum.sort(output_types),
               duration_ms: processing_duration_ms(item),
               attempt: item.processing_attempt,
               result: result,
               error_code: item.processing_error && item.processing_error["code"]
             }
           }) do
      :ok
    else
      {:error, reason} -> {:error, {:event_insert_failed, reason}}
    end
  end

  defp write_processing_transition_event(item, input_kind, from_state, to_state) do
    case Events.write_optional("operational.work_transition.v1", %{
           owner_id: item.owner_id,
           subject_type: "item",
           subject_id: to_string(item.id),
           run_id: item.processing_run_id,
           correlation_id: item.processing_run_id,
           details: %{
             operation: "process",
             input_kind: input_kind,
             from_state: Atom.to_string(from_state),
             to_state: Atom.to_string(to_state),
             attempt: item.processing_attempt,
             duration_ms: processing_duration_ms(item),
             error_code: item.processing_error && item.processing_error["code"]
           }
         }) do
      {:ok, _event} -> :ok
      {:error, reason} -> {:error, {:event_insert_failed, reason}}
    end
  end

  defp processing_input_kind(item), do: item.processing_capabilities["input_kind"]

  defp processing_duration_ms(%Item{processing_requested_at: nil}), do: 0

  defp processing_duration_ms(item) do
    DateTime.diff(DateTime.utc_now(), item.processing_requested_at, :millisecond)
    |> max(0)
  end

  defp terminal_result(:succeeded), do: "ok"
  defp terminal_result(:partial), do: "partial"
  defp terminal_result(:failed), do: "failed"

  defp item_client_id(attrs), do: item_attr(attrs, :client_id)

  defp matome_create_fingerprint(_attrs, nil), do: nil

  defp matome_create_fingerprint(attrs, _client_id) do
    {
      :matome,
      item_attr(attrs, :workspace_id),
      item_attr(attrs, :title),
      item_attr(attrs, :happened_at),
      item_attr(attrs, :description),
      item_attr(attrs, :aggregated_summary)
    }
    |> fingerprint()
  end

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
      item_attr(attrs, :original_extension),
      item_attr(attrs, :content_type),
      incoming_byte_size(attrs),
      item_attr(attrs, :checksum_sha256),
      item_attr(attrs, :duration),
      item_attr(attrs, :open_policy),
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

  defp prepare_file_attrs(attrs) do
    attrs =
      Map.drop(attrs, [:original_extension, "original_extension", :open_policy, "open_policy"])

    media_type = item_attr(attrs, :media_type)
    filename = item_attr(attrs, :filename)
    content_type = item_attr(attrs, :content_type)

    with {:ok, metadata} <- DocumentOpenPolicy.metadata(filename, content_type) do
      {:ok,
       attrs
       |> put_file_attr(
         :filename,
         if(media_type == "document" or not is_nil(filename), do: metadata.filename)
       )
       |> put_file_attr(:original_extension, metadata.original_extension)
       |> put_file_attr(
         :content_type,
         if(media_type == "document" or not is_nil(content_type), do: metadata.content_type)
       )
       |> put_file_attr(
         :open_policy,
         if(media_type == "document", do: metadata.open_policy, else: "download_only")
       )}
    end
  end

  defp put_file_attr(attrs, _key, nil), do: attrs

  defp put_file_attr(attrs, key, value) do
    if Enum.any?(Map.keys(attrs), &is_atom/1) do
      Map.put(attrs, key, value)
    else
      Map.put(attrs, Atom.to_string(key), value)
    end
  end

  defp persist_document_policy(%FileBlob{open_policy: policy} = blob, policy), do: {:ok, blob}

  defp persist_document_policy(blob, policy) do
    blob
    |> FileBlob.changeset(%{open_policy: policy})
    |> Repo.update()
  end

  defp block_unsafe_document(blob) do
    if DocumentOpenPolicy.current_policy(blob) == "blocked" do
      with {:ok, _blob} <- persist_document_policy(blob, "blocked") do
        {:error, :unsafe_file_type}
      end
    else
      :ok
    end
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
