defmodule MatomeApi.Admin.Work do
  @moduledoc """
  Metadata-only read projection across current Items, Oban dispatch, immutable
  Events, and each Device's latest queue observation.

  This module never selects Item titles/notes, file names/storage fields, output
  content, raw processing errors, Oban error payloads, or device-local identity.
  """

  import Ecto.Query

  alias MatomeApi.AIEngine.DispatchJob
  alias MatomeApi.Auth.Device
  alias MatomeApi.Content.{FileBlob, Item}
  alias MatomeApi.Events.Event
  alias MatomeApi.Repo
  alias MatomeApi.SystemConfig

  @limit 100
  @scan_limit 1_000
  @stable_errors ~w(
    transport timeout rate_limited server_unavailable unauthorized content_rejected
    invalid_local_data unexpected
  )

  def list(filters \\ %{}, now \\ DateTime.utc_now()) when is_map(filters) do
    desired_revision = SystemConfig.current_revision()
    stale_after = stale_after_seconds()
    observations = device_observations(now, stale_after, desired_revision)

    query =
      Item
      |> join(:left, [item], blob in FileBlob, on: blob.id == item.file_blob_id)
      |> order_by([item], desc: item.updated_at, desc: item.id)
      |> select([item, blob], %{
        id: item.id,
        owner_id: item.owner_id,
        item_type: item.item_type,
        source_revision: item.source_revision,
        inserted_at: item.inserted_at,
        updated_at: item.updated_at,
        processing_state: item.processing_state,
        processing_run_id: item.processing_run_id,
        processing_attempt: item.processing_attempt,
        processing_config_revision: item.processing_config_revision,
        processing_deadline_at: item.processing_deadline_at,
        processing_error_code: fragment("?->>'code'", item.processing_error),
        upload_state: blob.upload_state,
        upload_generation: blob.upload_generation,
        media_type: blob.media_type,
        byte_size: blob.byte_size
      })

    query =
      case filters[:item_id] do
        id when is_integer(id) -> where(query, [item], item.id == ^id)
        _no_item -> limit(query, ^@scan_limit)
      end

    items = Repo.all(query)

    jobs = jobs_by_item(Enum.map(items, & &1.id))

    items =
      items
      |> Enum.map(fn item ->
        observation = Map.get(observations.by_item, {item.owner_id, item.id})
        job = Map.get(jobs, item.id)

        error_code =
          stable_error(observation && observation.error_code, item.processing_error_code)

        item
        |> Map.put(:device_observation, observation)
        |> Map.put(:dispatch, safe_job(job))
        |> Map.put(:stage, stage(item, observation))
        |> Map.put(:error_code, error_code)
        |> Map.put(
          :age_seconds,
          (observation && observation.age_seconds) || age_seconds(now, item.inserted_at)
        )
      end)
      |> Enum.filter(&matches?(&1, filters))
      |> Enum.take(@limit)

    devices =
      observations.devices
      |> Enum.filter(&device_matches?(&1, filters))
      |> Enum.take(@limit)

    %{items: items, devices: devices}
  end

  def get_item(id, now \\ DateTime.utc_now()) when is_integer(id) do
    case list(%{item_id: id}, now).items |> List.first() do
      nil ->
        nil

      item ->
        events = id |> item_events(item.processing_run_id) |> Repo.all()

        Map.put(item, :events, events)
    end
  end

  defp device_observations(now, stale_after, desired_revision) do
    devices =
      from(device in Device,
        where: not is_nil(device.queue_snapshot),
        order_by: [desc: device.queue_reported_at, desc: device.id],
        limit: ^@scan_limit,
        select: %{
          id: device.id,
          owner_id: device.user_id,
          platform: device.platform,
          snapshot: device.queue_snapshot,
          reported_at: device.queue_reported_at,
          sequence: device.queue_report_sequence,
          applied_config_revision: device.applied_config_revision
        }
      )
      |> Repo.all()
      |> Enum.map(fn device ->
        device
        |> Map.put(:stale, age_seconds(now, device.reported_at) > stale_after)
        |> Map.put(
          :config_unacknowledged,
          device.applied_config_revision != desired_revision
        )
        |> Map.put(:oldest_age_seconds, device.snapshot["oldest_age_seconds"])
        |> Map.put(:counts, device.snapshot["counts"] || %{})
        |> Map.put(:stages, device.snapshot["stages"] || %{})
        |> Map.put(:errors, device.snapshot["errors"] || %{})
      end)

    by_item =
      Enum.reduce(devices, %{}, fn device, acc ->
        device.snapshot
        |> Map.get("items", [])
        |> Enum.reduce(acc, fn sample, item_acc ->
          key = {device.owner_id, sample["core_item_id"]}

          Map.put_new(item_acc, key, %{
            device_id: device.id,
            platform: device.platform,
            reported_at: device.reported_at,
            stale: device.stale,
            config_unacknowledged: device.config_unacknowledged,
            applied_config_revision: device.applied_config_revision,
            state: sample["state"],
            stage: sample["stage"],
            media_type: sample["media_type"],
            age_seconds: sample["age_seconds"],
            progress: sample["progress"],
            error_code: sample["error_code"]
          })
        end)
      end)

    %{devices: devices, by_item: by_item}
  end

  defp item_events(id, nil) do
    from(event in Event,
      where: event.subject_type == "item" and event.subject_id == ^to_string(id),
      order_by: [asc: event.occurred_at, asc: event.id],
      limit: 100
    )
  end

  defp item_events(id, run_id) do
    from(event in Event,
      where:
        (event.subject_type == "item" and event.subject_id == ^to_string(id)) or
          event.run_id == ^run_id,
      order_by: [asc: event.occurred_at, asc: event.id],
      limit: 100
    )
  end

  defp jobs_by_item([]), do: %{}

  defp jobs_by_item(item_ids) do
    item_ids = Enum.map(item_ids, &to_string/1)
    worker = DispatchJob |> Module.split() |> Enum.join(".")

    from(job in Oban.Job,
      where: job.worker == ^worker,
      where: fragment("?->>'item_id'", job.args) in ^item_ids,
      order_by: [desc: job.id]
    )
    |> Repo.all()
    |> Enum.reduce(%{}, fn job, acc ->
      case Integer.parse(to_string(job.args["item_id"])) do
        {item_id, ""} -> Map.put_new(acc, item_id, job)
        _invalid -> acc
      end
    end)
  end

  defp safe_job(nil), do: nil

  defp safe_job(job) do
    %{
      id: job.id,
      state: to_string(job.state),
      attempt: job.attempt,
      max_attempts: job.max_attempts,
      inserted_at: job.inserted_at,
      scheduled_at: job.scheduled_at,
      attempted_at: job.attempted_at,
      completed_at: job.completed_at,
      discarded_at: job.discarded_at
    }
  end

  defp stage(_item, %{stage: stage}) when is_binary(stage), do: "device:#{stage}"

  defp stage(%{upload_state: state}, _observation) when state not in [nil, "uploaded"],
    do: "upload:#{state}"

  defp stage(item, _observation), do: "processing:#{item.processing_state}"

  defp stable_error(device_error, _item_error) when device_error in @stable_errors,
    do: device_error

  defp stable_error(_device_error, item_error) when item_error in @stable_errors, do: item_error
  defp stable_error(_device_error, _item_error), do: nil

  defp matches?(item, filters) do
    matches_stage?(item.stage, filters[:stage]) and
      matches_value?(item.media_type || Atom.to_string(item.item_type), filters[:media]) and
      matches_value?(item.error_code, filters[:error]) and
      matches_device?(item.device_observation, filters[:device_id]) and
      matches_age?(item.age_seconds, filters[:min_age_seconds])
  end

  defp device_matches?(device, filters) do
    matches_device?(%{device_id: device.id}, filters[:device_id]) and
      map_has_key?(device.stages, filters[:stage]) and
      map_has_key?(device.errors, filters[:error]) and
      snapshot_has_media?(device.snapshot, filters[:media]) and
      matches_age?(device.oldest_age_seconds || 0, filters[:min_age_seconds])
  end

  defp matches_value?(_value, nil), do: true
  defp matches_value?(value, expected), do: value == expected
  defp matches_stage?(_stage, nil), do: true

  defp matches_stage?(stage, expected),
    do: stage == expected or String.ends_with?(stage, ":#{expected}")

  defp matches_device?(_observation, nil), do: true
  defp matches_device?(nil, _expected), do: false
  defp matches_device?(observation, expected), do: observation.device_id == expected
  defp matches_age?(_age, nil), do: true
  defp matches_age?(age, minimum), do: age >= minimum
  defp map_has_key?(_map, nil), do: true
  defp map_has_key?(map, key), do: Map.has_key?(map, key)
  defp snapshot_has_media?(_snapshot, nil), do: true

  defp snapshot_has_media?(snapshot, media) do
    Enum.any?(snapshot["items"] || [], &(&1["media_type"] == media))
  end

  defp age_seconds(now, timestamp) do
    max(DateTime.diff(now, timestamp, :second), 0)
  end

  defp stale_after_seconds do
    SystemConfig.desired()["queue"]["snapshot_interval_seconds"] * 2
  end
end
