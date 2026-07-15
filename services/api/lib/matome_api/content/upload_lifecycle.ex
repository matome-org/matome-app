defmodule MatomeApi.Content.UploadLifecycle do
  @moduledoc "Owner-scoped single and resumable multipart upload lifecycle."

  import Ecto.Query

  alias MatomeApi.Auth.User
  alias MatomeApi.Content.{FileBlob, Item, UploadCleanupJob}
  alias MatomeApi.Repo
  alias MatomeApi.Storage.{ObjectStore, Presigner, UploadPolicy}

  @checksum_pattern ~r/^[0-9a-f]{64}$/

  def request(%User{id: owner_id}, item_id, attrs \\ %{}) do
    transaction(fn ->
      with %Item{item_type: :file, file_blob: %FileBlob{} = blob} = item <-
             owned_item(owner_id, item_id, lock: true),
           :ok <- UploadPolicy.validate_size(blob.media_type, blob.byte_size),
           {:ok, checksum} <- requested_checksum(blob, attrs),
           {:ok, mode} <- requested_mode(blob, attrs) do
        request_locked(item, blob, mode, checksum)
      else
        %Item{item_type: :text} -> {:error, :text_item_not_presignable}
        nil -> nil
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  def inspect(%User{id: owner_id}, upload_id) do
    with {:ok, item_id, generation} <- parse_upload_id(upload_id) do
      transaction(fn ->
        case owned_item(owner_id, item_id, lock: true) do
          %Item{item_type: :file, file_blob: %FileBlob{} = blob} = item ->
            with :ok <- current_generation(blob, generation) do
              inspect_locked(item, blob)
            end

          %Item{item_type: :text} ->
            {:error, :text_item_not_presignable}

          nil ->
            nil
        end
      end)
    else
      {:error, _reason} -> nil
    end
  end

  def presign_part(%User{id: owner_id}, upload_id, part_number, attrs) do
    with {:ok, item_id, generation} <- parse_upload_id(upload_id),
         {:ok, part_number} <- cast_part_number(part_number) do
      transaction(fn ->
        case owned_item(owner_id, item_id, lock: true) do
          %Item{item_type: :file, file_blob: %FileBlob{} = blob} ->
            with :ok <- current_generation(blob, generation),
                 {:ok, context} <- active_context(blob),
                 :ok <- ensure_not_expired(blob, context),
                 {:ok, checksum} <- required_checksum(attrs),
                 byte_size when is_integer(byte_size) <-
                   context_part_byte_size(blob.byte_size, context, part_number),
                 {:ok, request} <-
                   ObjectStore.presign_part(
                     blob.storage_key,
                     context["provider_upload_id"],
                     part_number,
                     content_length: byte_size,
                     checksum_sha256: checksum
                   ) do
              {:ok,
               %{
                 part_number: part_number,
                 byte_size: byte_size,
                 checksum_sha256: checksum,
                 request: request_json(request)
               }}
            else
              {:error, reason} -> {:error, reason}
            end

          %Item{item_type: :text} ->
            {:error, :text_item_not_presignable}

          nil ->
            nil
        end
      end)
    else
      {:error, :invalid_upload_id} -> nil
      {:error, reason} -> {:error, reason}
    end
  end

  def complete(%User{id: owner_id}, upload_id, attrs) do
    with {:ok, item_id, generation} <- parse_upload_id(upload_id) do
      transaction(fn ->
        case owned_item(owner_id, item_id, lock: true) do
          %Item{item_type: :file, file_blob: %FileBlob{} = blob} = item ->
            case current_generation(blob, generation) do
              :ok ->
                with :ok <- body_generation(attrs, generation),
                     {:ok, checksum} <- requested_checksum(blob, attrs),
                     :ok <- require_checksum(checksum) do
                  complete_locked(item, blob, checksum, attrs)
                end

              {:error, :stale_upload_generation} ->
                {:ok, stale_descriptor(upload_id, generation)}
            end

          %Item{item_type: :text} ->
            {:error, :text_item_not_presignable}

          nil ->
            nil
        end
      end)
    else
      {:error, _reason} -> nil
    end
  end

  def abort(%User{id: owner_id}, upload_id, attrs \\ %{}) do
    with {:ok, item_id, generation} <- parse_upload_id(upload_id) do
      transaction(fn ->
        case owned_item(owner_id, item_id, lock: true) do
          %Item{item_type: :file, file_blob: %FileBlob{} = blob} ->
            case current_generation(blob, generation) do
              :ok ->
                with :ok <- body_generation(attrs, generation) do
                  abort_locked(blob)
                end

              {:error, :stale_upload_generation} ->
                {:ok, stale_descriptor(upload_id, generation)}
            end

          %Item{item_type: :text} ->
            {:error, :text_item_not_presignable}

          nil ->
            nil
        end
      end)
    else
      {:error, _reason} -> nil
    end
  end

  def expire(file_blob_id, generation, now \\ DateTime.utc_now()) do
    transaction(fn ->
      case FileBlob
           |> where([blob], blob.id == ^file_blob_id)
           |> lock("FOR UPDATE")
           |> Repo.one() do
        %FileBlob{
          upload_generation: ^generation,
          upload_state: "uploading",
          multipart_context: %{} = context
        } = blob ->
          if expired?(context, now) do
            with :ok <- abort_provider(blob, context),
                 {:ok, _blob} <- mark_failed(blob) do
              :ok
            end
          else
            :ok
          end

        _blob ->
          :ok
      end
    end)
  end

  defp request_locked(_item, %FileBlob{upload_state: "uploaded"} = blob, _mode, _checksum),
    do: {:ok, uploaded_descriptor(blob)}

  defp request_locked(item, blob, :single, checksum) do
    cond do
      is_map(blob.multipart_context) ->
        {:error, :multipart_upload_in_progress}

      blob.upload_state == "uploading" and
          UploadPolicy.mode_for(blob.media_type, blob.byte_size) == :multipart ->
        {:error, :multipart_required}

      true ->
        generation = retry_generation(blob)

        with :ok <- maybe_delete_failed_object(blob),
             {:ok, request} <-
               Presigner.presign_upload(blob.storage_key,
                 content_length: blob.byte_size,
                 checksum_sha256: checksum
               ),
             {:ok, updated} <-
               update_blob(blob, %{
                 upload_state: "uploading",
                 upload_generation: generation,
                 checksum_sha256: checksum,
                 uploaded_at: nil,
                 multipart_context: nil
               }) do
          {:ok, single_descriptor(item, updated, request)}
        end
    end
  end

  defp request_locked(item, blob, :multipart, checksum) do
    with :ok <- require_checksum(checksum) do
      case active_context(blob) do
        {:ok, context} ->
          if expired?(context) do
            with :ok <- abort_provider(blob, context),
                 {:ok, failed} <- mark_failed(blob) do
              start_multipart(item, failed, checksum)
            end
          else
            resume_multipart(item, blob, context)
          end

        {:error, :upload_not_active} ->
          start_multipart(item, blob, checksum)
      end
    end
  end

  defp start_multipart(item, blob, checksum) do
    generation = retry_generation(blob)
    upload_id = upload_id(item.id, generation)
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    expires_at = DateTime.add(now, UploadPolicy.multipart_ttl_seconds(), :second)

    with :ok <- maybe_delete_failed_object(blob),
         {:ok, %{upload_id: provider_upload_id}} <-
           ObjectStore.initiate_multipart(blob.storage_key,
             byte_size: blob.byte_size,
             checksum_sha256: checksum,
             content_type: blob.content_type
           ) do
      context = %{
        "upload_id" => upload_id,
        "provider_upload_id" => provider_upload_id,
        "generation" => generation,
        "part_size" => UploadPolicy.multipart_part_bytes(),
        "part_count" => UploadPolicy.part_count(blob.byte_size),
        "created_at" => DateTime.to_iso8601(now),
        "expires_at" => DateTime.to_iso8601(expires_at)
      }

      case update_blob(blob, %{
             upload_state: "uploading",
             upload_generation: generation,
             checksum_sha256: checksum,
             uploaded_at: nil,
             multipart_context: context
           }) do
        {:ok, updated} ->
          case schedule_cleanup(updated, expires_at) do
            {:ok, _job} ->
              multipart_descriptor(item, updated, context, [])

            {:error, reason} ->
              _ = abort_provider(updated, context)
              _ = mark_failed(updated)
              {:error, reason}
          end

        {:error, reason} ->
          _ = ObjectStore.abort_multipart(blob.storage_key, provider_upload_id)
          {:error, reason}
      end
    end
  end

  defp resume_multipart(item, blob, context) do
    case ObjectStore.list_parts(blob.storage_key, context["provider_upload_id"]) do
      {:ok, parts} ->
        multipart_descriptor(item, blob, context, parts)

      {:error, :no_such_upload} ->
        with {:ok, failed} <- mark_failed(blob) do
          start_multipart(item, failed, blob.checksum_sha256)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp inspect_locked(_item, %FileBlob{upload_state: "uploaded"} = blob),
    do: {:ok, uploaded_descriptor(blob)}

  defp inspect_locked(_item, %FileBlob{upload_state: state} = blob)
       when state in ["aborted", "failed"],
       do: {:ok, terminal_descriptor(blob)}

  defp inspect_locked(item, %FileBlob{multipart_context: %{} = context} = blob) do
    with :ok <- ensure_not_expired(blob, context),
         {:ok, parts} <- ObjectStore.list_parts(blob.storage_key, context["provider_upload_id"]) do
      multipart_descriptor(item, blob, context, parts)
    end
  end

  defp inspect_locked(_item, blob), do: {:ok, terminal_descriptor(blob)}

  defp complete_locked(_item, %FileBlob{upload_state: "uploaded"} = blob, _checksum, _attrs),
    do: {:ok, uploaded_descriptor(blob)}

  defp complete_locked(item, %FileBlob{multipart_context: %{} = context} = blob, checksum, attrs) do
    with :ok <- ensure_not_expired(blob, context) do
      case verify_head(blob, checksum, nil) do
        :ok ->
          mark_uploaded(blob, checksum)

        {:error, :not_found} ->
          complete_active_multipart(item, blob, context, checksum, attrs)

        {:error, :verification_failed} ->
          fail_verification(blob)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp complete_locked(_item, blob, checksum, attrs) do
    etag = attr(attrs, :etag)

    cond do
      blob.upload_state not in ["pending", "uploading"] ->
        {:error, :upload_not_active}

      UploadPolicy.mode_for(blob.media_type, blob.byte_size) == :multipart ->
        {:error, :upload_not_active}

      not is_binary(etag) or byte_size(etag) not in 1..1024 ->
        {:error, :etag_required}

      true ->
        case verify_head(blob, checksum, etag) do
          :ok -> mark_uploaded(blob, checksum)
          {:error, :verification_failed} -> fail_verification(blob)
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp complete_active_multipart(_item, blob, context, checksum, attrs) do
    with {:ok, requested_parts} <- complete_parts(attrs, context),
         {:ok, provider_parts} <-
           ObjectStore.list_parts(blob.storage_key, context["provider_upload_id"]),
         :ok <- verify_parts(requested_parts, provider_parts, blob.byte_size, context),
         :ok <-
           ObjectStore.complete_multipart(
             blob.storage_key,
             context["provider_upload_id"],
             requested_parts
           ) do
      case verify_head(blob, checksum, nil) do
        :ok -> mark_uploaded(blob, checksum)
        {:error, :verification_failed} -> fail_verification(blob)
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp verify_head(blob, checksum, expected_etag) do
    with {:ok, head} <- ObjectStore.head_object(blob.storage_key) do
      etag_matches =
        is_nil(expected_etag) or normalize_etag(head.etag) == normalize_etag(expected_etag)

      checksum_matches =
        head.checksum_sha256 == checksum or
          (is_nil(head.checksum_sha256) and verify_download_checksum(blob, checksum))

      if head.byte_size == blob.byte_size and checksum_matches and etag_matches do
        :ok
      else
        {:error, :verification_failed}
      end
    end
  end

  defp verify_download_checksum(blob, checksum) do
    if UploadPolicy.mode_for(blob.media_type, blob.byte_size) == :single do
      case ObjectStore.get_object(blob.storage_key) do
        {:ok, body} ->
          body
          |> then(&:crypto.hash(:sha256, &1))
          |> Base.encode16(case: :lower)
          |> Kernel.==(checksum)

        {:error, _reason} ->
          false
      end
    else
      false
    end
  end

  defp complete_parts(attrs, context) do
    parts = attr(attrs, :parts)
    expected_count = context["part_count"]

    if is_list(parts) and length(parts) == expected_count do
      parsed = Enum.map(parts, &parse_complete_part/1)

      with nil <- Enum.find(parsed, &match?({:error, _reason}, &1)),
           parsed <- Enum.map(parsed, fn {:ok, part} -> part end),
           true <- Enum.map(parsed, & &1.part_number) == Enum.to_list(1..expected_count) do
        {:ok, parsed}
      else
        {:error, reason} -> {:error, reason}
        false -> {:error, :invalid_parts}
      end
    else
      {:error, :invalid_parts}
    end
  end

  defp parse_complete_part(part) when is_map(part) do
    with {:ok, part_number} <- cast_part_number(attr(part, :part_number)),
         etag when is_binary(etag) and byte_size(etag) in 1..1024 <- attr(part, :etag),
         {:ok, checksum} <- required_checksum(part) do
      {:ok, %{part_number: part_number, etag: normalize_etag(etag), checksum_sha256: checksum}}
    else
      _ -> {:error, :invalid_parts}
    end
  end

  defp parse_complete_part(_part), do: {:error, :invalid_parts}

  defp verify_parts(requested, provider, byte_size, context) do
    provider_by_number = Map.new(provider, &{&1.part_number, &1})

    valid =
      length(requested) == length(provider) and
        Enum.all?(requested, fn requested_part ->
          case provider_by_number[requested_part.part_number] do
            nil ->
              false

            provider_part ->
              provider_part.byte_size ==
                context_part_byte_size(byte_size, context, requested_part.part_number) and
                normalize_etag(provider_part.etag) == requested_part.etag and
                provider_part.checksum_sha256 == requested_part.checksum_sha256
          end
        end)

    if valid, do: :ok, else: {:error, :part_verification_failed}
  end

  defp mark_uploaded(blob, checksum) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    with {:ok, uploaded} <-
           update_blob(blob, %{
             upload_state: "uploaded",
             checksum_sha256: checksum,
             uploaded_at: now,
             multipart_context: nil
           }) do
      {:ok, uploaded_descriptor(uploaded)}
    end
  end

  defp fail_verification(blob) do
    cleanup_result =
      case blob.multipart_context do
        %{} = context -> abort_provider(blob, context)
        nil -> ObjectStore.delete_object(blob.storage_key)
      end

    with :ok <- cleanup_result,
         {:ok, _failed} <- mark_failed(blob) do
      {:error, :verification_failed}
    end
  end

  defp abort_locked(%FileBlob{upload_state: "aborted"} = blob),
    do: {:ok, terminal_descriptor(blob)}

  defp abort_locked(%FileBlob{upload_state: "uploaded"} = blob),
    do: {:ok, uploaded_descriptor(blob)}

  defp abort_locked(%FileBlob{multipart_context: %{} = context} = blob) do
    with :ok <- abort_provider(blob, context),
         {:ok, aborted} <-
           update_blob(blob, %{upload_state: "aborted", uploaded_at: nil, multipart_context: nil}) do
      {:ok, terminal_descriptor(aborted)}
    end
  end

  defp abort_locked(blob) do
    with :ok <- ObjectStore.delete_object(blob.storage_key),
         {:ok, aborted} <-
           update_blob(blob, %{upload_state: "aborted", uploaded_at: nil, multipart_context: nil}) do
      {:ok, terminal_descriptor(aborted)}
    end
  end

  defp abort_provider(blob, context) do
    with :ok <- ObjectStore.abort_multipart(blob.storage_key, context["provider_upload_id"]),
         :ok <- ObjectStore.delete_object(blob.storage_key) do
      :ok
    end
  end

  defp ensure_not_expired(blob, context) do
    if expired?(context) do
      with :ok <- abort_provider(blob, context),
           {:ok, _failed} <- mark_failed(blob) do
        {:error, :upload_expired}
      end
    else
      :ok
    end
  end

  defp expired?(context, now \\ DateTime.utc_now()) do
    with expires_at when is_binary(expires_at) <- context["expires_at"],
         {:ok, expires_at, _offset} <- DateTime.from_iso8601(expires_at) do
      DateTime.compare(expires_at, now) != :gt
    else
      _ -> true
    end
  end

  defp active_context(%FileBlob{upload_state: "uploading", multipart_context: %{} = context}),
    do: {:ok, context}

  defp active_context(_blob), do: {:error, :upload_not_active}

  defp mark_failed(blob) do
    update_blob(blob, %{upload_state: "failed", uploaded_at: nil, multipart_context: nil})
  end

  defp maybe_delete_failed_object(%FileBlob{upload_state: state, storage_key: storage_key})
       when state in ["failed", "aborted"] do
    ObjectStore.delete_object(storage_key)
  end

  defp maybe_delete_failed_object(_blob), do: :ok

  defp retry_generation(%FileBlob{upload_state: state, upload_generation: generation})
       when state in ["failed", "aborted"],
       do: generation + 1

  defp retry_generation(%FileBlob{upload_generation: generation}), do: generation

  defp requested_mode(blob, attrs) do
    policy_mode = UploadPolicy.mode_for(blob.media_type, blob.byte_size)

    case attr(attrs, :mode) do
      nil -> {:ok, policy_mode}
      "auto" -> {:ok, policy_mode}
      "single" when policy_mode == :single -> {:ok, :single}
      "single" -> {:error, :multipart_required}
      "multipart" when policy_mode == :multipart -> {:ok, :multipart}
      "multipart" -> {:error, :single_upload_required}
      _ -> {:error, :invalid_upload_mode}
    end
  end

  defp requested_checksum(blob, attrs) do
    incoming = attr(attrs, :checksum_sha256)

    cond do
      is_nil(incoming) -> {:ok, blob.checksum_sha256}
      not valid_checksum?(incoming) -> {:error, :invalid_checksum}
      is_nil(blob.checksum_sha256) -> {:ok, incoming}
      blob.checksum_sha256 == incoming -> {:ok, incoming}
      true -> {:error, :checksum_mismatch}
    end
  end

  defp required_checksum(attrs) do
    checksum = attr(attrs, :checksum_sha256)
    if valid_checksum?(checksum), do: {:ok, checksum}, else: {:error, :invalid_checksum}
  end

  defp require_checksum(checksum) do
    if valid_checksum?(checksum), do: :ok, else: {:error, :checksum_required}
  end

  defp valid_checksum?(checksum),
    do: is_binary(checksum) and Regex.match?(@checksum_pattern, checksum)

  defp body_generation(attrs, expected) do
    case attr(attrs, :upload_generation) do
      nil ->
        :ok

      ^expected ->
        :ok

      value when is_binary(value) ->
        case Integer.parse(value) do
          {^expected, ""} -> :ok
          _ -> {:error, :stale_upload_generation}
        end

      _ ->
        {:error, :stale_upload_generation}
    end
  end

  defp current_generation(%FileBlob{upload_generation: generation}, generation), do: :ok
  defp current_generation(_blob, _generation), do: {:error, :stale_upload_generation}

  defp cast_part_number(value) when is_integer(value) and value in 1..10_000, do: {:ok, value}

  defp cast_part_number(value) when is_binary(value) do
    case Integer.parse(value) do
      {part_number, ""} when part_number in 1..10_000 -> {:ok, part_number}
      _ -> {:error, :invalid_part_number}
    end
  end

  defp cast_part_number(_value), do: {:error, :invalid_part_number}

  defp context_part_byte_size(byte_size, context, part_number) do
    part_count = context["part_count"]
    part_size = context["part_size"]

    if is_integer(part_count) and part_count > 0 and is_integer(part_size) and part_size > 0 and
         part_number >= 1 and part_number <= part_count do
      min(part_size, byte_size - (part_number - 1) * part_size)
    else
      {:error, :invalid_part_number}
    end
  end

  defp parse_upload_id(upload_id) when is_binary(upload_id) do
    case Regex.run(~r/^item-([1-9][0-9]*)-upload-([1-9][0-9]*)$/, upload_id,
           capture: :all_but_first
         ) do
      [item_id, generation] -> {:ok, String.to_integer(item_id), String.to_integer(generation)}
      _ -> {:error, :invalid_upload_id}
    end
  end

  defp parse_upload_id(_upload_id), do: {:error, :invalid_upload_id}

  defp owned_item(owner_id, item_id, opts) do
    query =
      Item
      |> where([item], item.id == ^item_id and item.owner_id == ^owner_id)
      |> maybe_lock(opts[:lock])

    query |> Repo.one() |> Repo.preload(:file_blob)
  end

  defp maybe_lock(query, true), do: lock(query, "FOR UPDATE")
  defp maybe_lock(query, _lock), do: query

  defp update_blob(blob, attrs), do: blob |> FileBlob.changeset(attrs) |> Repo.update()

  defp schedule_cleanup(blob, expires_at) do
    %{"file_blob_id" => blob.id, "upload_generation" => blob.upload_generation}
    |> UploadCleanupJob.new(
      scheduled_at: expires_at,
      unique: [period: UploadPolicy.multipart_ttl_seconds(), fields: [:args]]
    )
    |> Oban.insert()
  end

  defp single_descriptor(item, blob, request) do
    %{
      upload_id: upload_id(item.id, blob.upload_generation),
      upload_generation: blob.upload_generation,
      mode: "single",
      state: blob.upload_state,
      expires_at: request.expires_at,
      request: request_json(request)
    }
  end

  defp multipart_descriptor(item, blob, context, parts) do
    accepted_parts = Enum.map(parts, &part_json/1)
    accepted_numbers = MapSet.new(parts, & &1.part_number)

    missing_parts =
      1..context["part_count"]
      |> Enum.reject(&MapSet.member?(accepted_numbers, &1))

    {:ok,
     %{
       upload_id: upload_id(item.id, blob.upload_generation),
       upload_generation: blob.upload_generation,
       mode: "multipart",
       state: blob.upload_state,
       part_size: context["part_size"],
       accepted_parts: accepted_parts,
       missing_parts: missing_parts,
       expires_at: context["expires_at"]
     }}
  end

  defp uploaded_descriptor(blob) do
    %{
      upload_id: upload_id_for_blob(blob),
      upload_generation: blob.upload_generation,
      mode: mode_string(blob),
      state: "uploaded",
      verified_byte_size: blob.byte_size,
      verified_checksum_sha256: blob.checksum_sha256,
      completed_at: blob.uploaded_at
    }
  end

  defp terminal_descriptor(blob) do
    %{
      upload_id: upload_id_for_blob(blob),
      upload_generation: blob.upload_generation,
      mode: mode_string(blob),
      state: blob.upload_state
    }
  end

  defp stale_descriptor(upload_id, generation) do
    %{
      upload_id: upload_id,
      upload_generation: generation,
      state: "stale"
    }
  end

  defp upload_id_for_blob(blob) do
    item_id = Repo.one(from item in Item, where: item.file_blob_id == ^blob.id, select: item.id)
    upload_id(item_id, blob.upload_generation)
  end

  defp upload_id(item_id, generation), do: "item-#{item_id}-upload-#{generation}"

  defp mode_string(blob) do
    blob.media_type |> UploadPolicy.mode_for(blob.byte_size) |> Atom.to_string()
  end

  defp request_json(request) do
    %{method: request.method, url: request.url, headers: request.headers}
  end

  defp part_json(part) do
    %{
      part_number: part.part_number,
      etag: part.etag,
      checksum_sha256: part.checksum_sha256,
      byte_size: part.byte_size
    }
  end

  defp normalize_etag(nil), do: nil
  defp normalize_etag(etag), do: etag |> to_string() |> String.trim("\"")

  defp attr(attrs, key) when is_map(attrs) do
    Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key))
  end

  defp transaction(fun) do
    case Repo.transaction(fun) do
      {:ok, result} -> result
      {:error, reason} -> {:error, reason}
    end
  end
end
