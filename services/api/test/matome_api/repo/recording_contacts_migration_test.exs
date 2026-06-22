defmodule MatomeApi.Repo.RecordingContactsMigrationTest do
  # Exercises the `recording_contacts` migration UP and DOWN (#1472) inside the
  # SQL sandbox so every DDL change is rolled back at the end of the test (the
  # rest of the suite — and the persistent test DB — keep the migrated table).
  # Runs the migration module's own `up/0` and `down/0` through the migration
  # Runner so the rollback path is genuinely exercised, not re-derived.
  use MatomeApi.DataCase, async: false

  alias Ecto.Migration.Runner
  alias MatomeApi.Repo

  # Migration modules live in priv/ and are not compiled into the app, so load
  # the file to bring the module into scope.
  Code.require_file(
    "priv/repo/migrations/20260622070000_create_recording_contacts.exs",
    File.cwd!()
  )

  alias MatomeApi.Repo.Migrations.CreateRecordingContacts

  @table "recording_contacts"
  @version 20_260_622_070_000

  # Execute the migration module's own `up/0`/`down/0` literally (forward — the
  # `down/0` body already issues the DROP, so it must NOT be auto-reversed).
  defp run(operation) do
    Runner.run(Repo, [], @version, CreateRecordingContacts, :forward, operation, :forward,
      log: false
    )
  end

  test "down drops the table; up recreates it with the unique (recording_id, contact_id) index" do
    assert table_exists?()

    # DOWN — the migration's own `down/0` must drop the table cleanly.
    run(:down)
    refute table_exists?()

    # UP — recreate it, then assert the unique index is back.
    run(:up)
    assert table_exists?()
    assert unique_index_present?()
  end

  defp table_exists? do
    %{rows: [[count]]} =
      Repo.query!(
        "SELECT count(*) FROM information_schema.tables WHERE table_name = $1",
        [@table]
      )

    count == 1
  end

  defp unique_index_present? do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT indexname FROM pg_indexes
        WHERE tablename = $1 AND indexdef ILIKE '%UNIQUE%'
          AND indexdef ILIKE '%recording_id%' AND indexdef ILIKE '%contact_id%'
        """,
        [@table]
      )

    rows != []
  end
end
