defmodule MatomeApi.Auth.DeviceQueueSnapshot do
  @moduledoc """
  Strict wire validator for the latest device queue observation.

  Exact allowlists keep paths, names, local identifiers, content, credentials,
  and raw errors out of the persisted JSONB by construction.
  """

  @max_bytes 65_536
  @max_count 1_000_000
  @max_age_seconds 315_360_000
  @max_items 100
  @max_sequence 9_223_372_036_854_775_807

  @states ~w(queued running retry blocked dead)
  @stages ~w(
    reconcile_parent create_remote hash_file request_upload upload upload_single
    upload_parts complete_upload enqueue_processing processing_accepted
    upload_only_complete
  )
  @media_types ~w(audio image document video)
  @error_codes ~w(
    transport timeout rate_limited server_unavailable unauthorized content_rejected
    invalid_local_data unexpected
  )
  @snapshot_keys ~w(counts stages errors oldest_age_seconds progress items)
  @item_keys ~w(core_item_id state stage media_type age_seconds progress error_code)

  def validate(
        %{
          "contract_version" => "1",
          "sequence" => sequence,
          "applied_config_revision" => revision,
          "snapshot" => snapshot
        } = report,
        current_revision
      )
      when map_size(report) == 4 and is_integer(sequence) and is_integer(revision) and
             is_integer(current_revision) do
    with true <- sequence in 1..@max_sequence,
         true <- revision in 0..current_revision,
         {:ok, snapshot} <- validate_snapshot(snapshot),
         {:ok, encoded} <- Jason.encode(snapshot),
         true <- byte_size(encoded) <= @max_bytes do
      {:ok, %{sequence: sequence, applied_config_revision: revision, snapshot: snapshot}}
    else
      _invalid -> {:error, :invalid_queue_snapshot}
    end
  end

  def validate(_report, _current_revision), do: {:error, :invalid_queue_snapshot}

  defp validate_snapshot(snapshot) when is_map(snapshot) do
    allowed_keys = @snapshot_keys ++ ["local_spaces"]

    with true <- exact_keys?(snapshot, @snapshot_keys, allowed_keys),
         true <- count_map?(snapshot["counts"], @states),
         true <- count_map?(snapshot["stages"], @stages),
         true <- count_map?(snapshot["errors"], @error_codes),
         true <- age?(snapshot["oldest_age_seconds"]),
         true <- progress_summary?(snapshot["progress"]),
         true <- items?(snapshot["items"]),
         true <- local_spaces?(Map.get(snapshot, "local_spaces")) do
      {:ok, snapshot}
    else
      _invalid -> {:error, :invalid_queue_snapshot}
    end
  end

  defp validate_snapshot(_snapshot), do: {:error, :invalid_queue_snapshot}

  defp exact_keys?(map, required, allowed) when is_map(map) do
    keys = Map.keys(map)
    Enum.all?(required, &(&1 in keys)) and Enum.all?(keys, &(&1 in allowed))
  end

  defp exact_keys?(_map, _required, _allowed), do: false

  defp count_map?(map, allowed_keys) when is_map(map) and map_size(map) <= length(allowed_keys) do
    Enum.all?(map, fn {key, value} ->
      key in allowed_keys and is_integer(value) and value in 0..@max_count
    end)
  end

  defp count_map?(_map, _allowed_keys), do: false

  defp age?(nil), do: true
  defp age?(age), do: is_integer(age) and age in 0..@max_age_seconds

  defp progress_summary?(%{"average" => average, "minimum" => minimum} = progress)
       when map_size(progress) == 2,
       do: progress?(average) and progress?(minimum)

  defp progress_summary?(_progress), do: false

  defp progress?(value), do: is_number(value) and value >= 0 and value <= 1

  defp items?(items) when is_list(items) and length(items) <= @max_items do
    Enum.all?(items, &item?/1) and
      items
      |> Enum.map(& &1["core_item_id"])
      |> then(&(Enum.uniq(&1) == &1))
  end

  defp items?(_items), do: false

  defp item?(item) when is_map(item) and map_size(item) == length(@item_keys) do
    exact_keys?(item, @item_keys, @item_keys) and
      is_integer(item["core_item_id"]) and item["core_item_id"] > 0 and
      item["state"] in @states and item["stage"] in @stages and
      item["media_type"] in @media_types and age?(item["age_seconds"]) and
      progress?(item["progress"]) and
      (is_nil(item["error_code"]) or item["error_code"] in @error_codes)
  end

  defp item?(_item), do: false

  defp local_spaces?(nil), do: true

  defp local_spaces?(%{"work_count" => count, "oldest_age_seconds" => age} = local)
       when map_size(local) == 2,
       do: is_integer(count) and count in 0..@max_count and age?(age)

  defp local_spaces?(_local), do: false
end
