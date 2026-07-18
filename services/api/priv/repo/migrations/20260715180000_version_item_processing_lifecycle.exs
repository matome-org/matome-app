defmodule MatomeApi.Repo.Migrations.VersionItemProcessingLifecycle do
  use Ecto.Migration

  def up do
    drop constraint(:items, :items_processing_state_check)
    drop constraint(:items, :items_processing_run_check)
    drop constraint(:items, :items_processing_error_check)

    alter table(:items) do
      add :processing_attempt, :bigint, null: false, default: 0
      add :processing_capabilities, :map
      add :processing_requested_outputs, {:array, :string}, null: false, default: []
      add :processing_requested_at, :utc_datetime
      add :processing_deadline_at, :utc_datetime
    end

    create constraint(:items, :items_processing_state_check,
             check:
               "processing_state IN ('not_requested', 'not_available', 'queued', 'processing', 'succeeded', 'partial', 'failed')"
           )

    create constraint(:items, :items_processing_run_check,
             check: """
             (
               processing_state = 'not_requested'
               AND processing_run_id IS NULL
               AND processing_attempt = 0
               AND processing_config_revision IS NULL
               AND processing_capabilities IS NULL
               AND cardinality(processing_requested_outputs) = 0
                AND processing_requested_at IS NULL
                AND processing_deadline_at IS NULL
                AND processing_outputs = '{}'::jsonb
                AND processing_error IS NULL
             )
             OR
             (
               processing_state != 'not_requested'
               AND processing_run_id IS NOT NULL
               AND processing_attempt > 0
               AND processing_config_revision IS NOT NULL
               AND processing_capabilities IS NOT NULL
               AND processing_requested_at IS NOT NULL
               AND processing_deadline_at IS NOT NULL
             )
             """
           )

    create constraint(:items, :items_processing_capabilities_check,
             check: """
             processing_capabilities IS NULL
             OR (
               jsonb_typeof(processing_capabilities) = 'object'
               AND octet_length(processing_capabilities::text) <= 65536
             )
             """
           )

    create constraint(:items, :items_processing_requested_outputs_check,
             check: """
             cardinality(processing_requested_outputs) <= 10
             AND processing_requested_outputs <@ ARRAY[
               'transcript', 'ocr_text', 'description', 'extracted_text', 'summary', 'title'
             ]::varchar[]
             """
           )

    create constraint(:items, :items_processing_error_check,
             check: """
             processing_error IS NULL
             OR (
               processing_state = 'failed'
               AND jsonb_typeof(processing_error) = 'object'
               AND octet_length(processing_error::text) <= 16384
             )
             """
           )
  end

  def down do
    drop constraint(:items, :items_processing_error_check)
    drop constraint(:items, :items_processing_requested_outputs_check)
    drop constraint(:items, :items_processing_capabilities_check)
    drop constraint(:items, :items_processing_run_check)
    drop constraint(:items, :items_processing_state_check)

    alter table(:items) do
      remove :processing_deadline_at
      remove :processing_requested_at
      remove :processing_requested_outputs
      remove :processing_capabilities
      remove :processing_attempt
    end

    create constraint(:items, :items_processing_state_check,
             check:
               "processing_state IN ('not_requested', 'queued', 'processing', 'succeeded', 'failed')"
           )

    create constraint(:items, :items_processing_run_check,
             check: """
             (processing_state = 'not_requested' AND processing_run_id IS NULL)
             OR
             (processing_state != 'not_requested' AND processing_run_id IS NOT NULL)
             """
           )

    create constraint(:items, :items_processing_error_check,
             check: """
             processing_error IS NULL
             OR (
               processing_state = 'failed'
               AND jsonb_typeof(processing_error) = 'object'
               AND octet_length(processing_error::text) <= 16384
             )
             """
           )
  end
end
