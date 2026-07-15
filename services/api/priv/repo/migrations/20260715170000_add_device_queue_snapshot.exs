defmodule MatomeApi.Repo.Migrations.AddDeviceQueueSnapshot do
  use Ecto.Migration

  def change do
    alter table(:devices) do
      add :queue_snapshot, :map
      add :queue_reported_at, :utc_datetime
      add :queue_report_sequence, :bigint, null: false, default: 0
      add :applied_config_revision, :bigint
    end

    create constraint(:devices, :devices_queue_snapshot_current_check,
             check: """
             (
               queue_snapshot IS NULL
               AND queue_reported_at IS NULL
               AND queue_report_sequence = 0
               AND applied_config_revision IS NULL
             )
             OR
             (
               jsonb_typeof(queue_snapshot) = 'object'
               AND octet_length(queue_snapshot::text) <= 65536
               AND queue_reported_at IS NOT NULL
               AND queue_report_sequence > 0
               AND applied_config_revision >= 0
             )
             """
           )
  end
end
