defmodule MatomeApi.Auth.DeviceQueueReports do
  @moduledoc "Updates one owner-scoped Device with its latest monotonic queue observation."

  import Ecto.Query

  alias MatomeApi.Auth.{Device, DeviceQueueSnapshot, User}
  alias MatomeApi.Repo
  alias MatomeApi.SystemConfig

  def report(%User{id: owner_id}, device_id, params, now \\ DateTime.utc_now()) do
    with device_id when is_integer(device_id) <- device_id,
         {:ok, report} <- DeviceQueueSnapshot.validate(params, SystemConfig.current_revision()) do
      now = DateTime.truncate(now, :second)

      {updated, _rows} =
        from(device in Device,
          where:
            device.id == ^device_id and device.user_id == ^owner_id and
              device.queue_report_sequence < ^report.sequence
        )
        |> Repo.update_all(
          set: [
            queue_snapshot: report.snapshot,
            queue_reported_at: now,
            queue_report_sequence: report.sequence,
            applied_config_revision: report.applied_config_revision,
            last_seen_at: now,
            updated_at: now
          ]
        )

      cond do
        updated == 1 ->
          :ok

        Repo.exists?(from d in Device, where: d.id == ^device_id and d.user_id == ^owner_id) ->
          :ok

        true ->
          {:error, :device_not_registered}
      end
    else
      nil -> {:error, :device_not_registered}
      {:error, reason} -> {:error, reason}
    end
  end
end
