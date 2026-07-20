defmodule MatomeApi.Admin.Dashboard do
  @moduledoc """
  Aggregations for the `/admin` landing dashboard.

  Activity is the same degraded signal as Sessions: `last_seen_at` within
  `activity_window_seconds/0` (5 minutes). Storage sums client-declared
  `file_blobs.byte_size` — metadata only, ZK-safe.
  """

  import Ecto.Query

  alias MatomeApi.Auth.{Device, RefreshToken, User}
  alias MatomeApi.Content.{FileBlob, Item, Matome, Workspace}
  alias MatomeApi.Repo

  @activity_window_seconds 5 * 60

  @doc "Shared activity window (seconds) — matches Sessions “active recently”."
  def activity_window_seconds, do: @activity_window_seconds

  @doc """
  Snapshot for the admin landing charts.

  Returns:

      %{
        users: %{total: n, active: n, inactive: n},
        devices: %{total: n, active: n, inactive: n},
        platforms: [%{platform: "ios", count: n}, ...],
        form_factors: [%{form_factor: "desktop", count: n}, ...],
        device_classes: [%{device_class: "laptop", count: n}, ...],
        storage: %{
          by_workspace: [%{id: id, name: name, bytes: n}, ...],
          unfiled_bytes: n,
          total_bytes: n
        }
      }
  """
  def stats(now \\ DateTime.utc_now()) do
    now = DateTime.truncate(now, :second)
    cutoff = DateTime.add(now, -@activity_window_seconds, :second)

    %{
      users: user_activity(cutoff),
      devices: device_activity(cutoff),
      platforms: enum_breakdown(:platform),
      form_factors: enum_breakdown(:form_factor),
      device_classes: enum_breakdown(:device_class),
      storage: storage_breakdown()
    }
  end

  defp user_activity(cutoff) do
    total = Repo.aggregate(User, :count, :id)

    last_seen_by_user =
      device_last_seen()
      |> Map.merge(token_last_seen(), fn _k, a, b -> max_dt(a, b) end)

    active =
      last_seen_by_user
      |> Map.values()
      |> Enum.count(&(DateTime.compare(&1, cutoff) != :lt))

    inactive = max(total - active, 0)

    %{total: total, active: active, inactive: inactive}
  end

  defp device_last_seen do
    from(d in Device,
      where: not is_nil(d.last_seen_at),
      group_by: d.user_id,
      select: {d.user_id, max(d.last_seen_at)}
    )
    |> Repo.all()
    |> Map.new()
  end

  defp token_last_seen do
    from(t in RefreshToken,
      where: not is_nil(t.last_seen_at),
      group_by: t.user_id,
      select: {t.user_id, max(t.last_seen_at)}
    )
    |> Repo.all()
    |> Map.new()
  end

  defp max_dt(a, b) do
    case DateTime.compare(a, b) do
      :lt -> b
      _ -> a
    end
  end

  defp device_activity(cutoff) do
    total = Repo.aggregate(Device, :count, :id)

    active =
      from(d in Device, where: not is_nil(d.last_seen_at) and d.last_seen_at >= ^cutoff)
      |> Repo.aggregate(:count, :id)

    %{total: total, active: active, inactive: max(total - active, 0)}
  end

  defp enum_breakdown(:platform) do
    from(d in Device,
      group_by: fragment("COALESCE(NULLIF(TRIM(?), ''), 'unknown')", d.platform),
      select: {fragment("COALESCE(NULLIF(TRIM(?), ''), 'unknown')", d.platform), count(d.id)},
      order_by: [
        desc: count(d.id),
        asc: fragment("COALESCE(NULLIF(TRIM(?), ''), 'unknown')", d.platform)
      ]
    )
    |> Repo.all()
    |> Enum.map(fn {value, count} -> %{platform: value, count: count} end)
  end

  defp enum_breakdown(:form_factor) do
    from(d in Device,
      group_by: fragment("COALESCE(NULLIF(TRIM(?), ''), 'unknown')", d.form_factor),
      select: {fragment("COALESCE(NULLIF(TRIM(?), ''), 'unknown')", d.form_factor), count(d.id)},
      order_by: [
        desc: count(d.id),
        asc: fragment("COALESCE(NULLIF(TRIM(?), ''), 'unknown')", d.form_factor)
      ]
    )
    |> Repo.all()
    |> Enum.map(fn {value, count} -> %{form_factor: value, count: count} end)
  end

  defp enum_breakdown(:device_class) do
    from(d in Device,
      group_by: fragment("COALESCE(NULLIF(TRIM(?), ''), 'unknown')", d.device_class),
      select: {fragment("COALESCE(NULLIF(TRIM(?), ''), 'unknown')", d.device_class), count(d.id)},
      order_by: [
        desc: count(d.id),
        asc: fragment("COALESCE(NULLIF(TRIM(?), ''), 'unknown')", d.device_class)
      ]
    )
    |> Repo.all()
    |> Enum.map(fn {value, count} -> %{device_class: value, count: count} end)
  end

  defp storage_breakdown do
    usage_by_workspace =
      from(i in Item,
        left_join: m in Matome,
        on: m.id == i.matome_id,
        join: fb in FileBlob,
        on: fb.id == i.file_blob_id,
        where: i.item_type == :file,
        where:
          not is_nil(
            fragment(
              "CASE WHEN ? IS NOT NULL THEN ? ELSE ? END",
              i.matome_id,
              m.workspace_id,
              i.workspace_id
            )
          ),
        group_by:
          fragment(
            "CASE WHEN ? IS NOT NULL THEN ? ELSE ? END",
            i.matome_id,
            m.workspace_id,
            i.workspace_id
          ),
        select: {
          fragment(
            "CASE WHEN ? IS NOT NULL THEN ? ELSE ? END",
            i.matome_id,
            m.workspace_id,
            i.workspace_id
          ),
          coalesce(sum(fb.byte_size), 0)
        }
      )
      |> Repo.all()
      |> Map.new(fn {workspace_id, bytes} -> {workspace_id, to_non_neg_int(bytes)} end)

    by_workspace =
      Workspace
      |> Repo.all()
      |> Enum.map(fn workspace ->
        %{
          id: workspace.id,
          name: workspace.name,
          bytes: Map.get(usage_by_workspace, workspace.id, 0)
        }
      end)
      |> Enum.sort_by(&{-&1.bytes, &1.name})

    unfiled_bytes =
      from(i in Item,
        left_join: m in Matome,
        on: m.id == i.matome_id,
        join: fb in FileBlob,
        on: fb.id == i.file_blob_id,
        where: i.item_type == :file,
        where:
          is_nil(
            fragment(
              "CASE WHEN ? IS NOT NULL THEN ? ELSE ? END",
              i.matome_id,
              m.workspace_id,
              i.workspace_id
            )
          ),
        select: coalesce(sum(fb.byte_size), 0)
      )
      |> Repo.one()
      |> to_non_neg_int()

    workspace_total = Enum.reduce(by_workspace, 0, fn row, acc -> acc + row.bytes end)

    %{
      by_workspace: by_workspace,
      unfiled_bytes: unfiled_bytes,
      total_bytes: workspace_total + unfiled_bytes
    }
  end

  defp to_non_neg_int(nil), do: 0
  defp to_non_neg_int(%Decimal{} = d), do: d |> Decimal.to_integer()
  defp to_non_neg_int(n) when is_integer(n) and n >= 0, do: n
  defp to_non_neg_int(n) when is_float(n), do: trunc(n)
  defp to_non_neg_int(_), do: 0
end
