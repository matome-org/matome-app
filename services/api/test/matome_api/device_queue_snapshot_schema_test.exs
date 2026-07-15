defmodule MatomeApi.DeviceQueueSnapshotSchemaTest do
  use MatomeApi.DataCase, async: true

  alias MatomeApi.Repo

  test "devices own one current bounded snapshot and no report history table exists" do
    assert columns("devices") >=
             MapSet.new(~w(
               queue_snapshot queue_reported_at queue_report_sequence applied_config_revision
             ))

    refute table_exists?("device_queue_reports")
    refute table_exists?("queue_snapshots")
  end

  defp columns(table) do
    %{rows: rows} =
      Repo.query!(
        "SELECT column_name FROM information_schema.columns WHERE table_schema = 'public' AND table_name = $1",
        [table]
      )

    rows |> Enum.map(&hd/1) |> MapSet.new()
  end

  defp table_exists?(table) do
    %{rows: [[exists?]]} = Repo.query!("SELECT to_regclass($1) IS NOT NULL", ["public.#{table}"])
    exists?
  end
end
