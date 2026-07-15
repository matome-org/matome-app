defmodule MatomeApi.Repo.EventsSchemaTest do
  use MatomeApi.DataCase, async: true

  alias MatomeApi.Events
  alias MatomeApi.Events.Event

  test "events is the only event instance table" do
    assert %{rows: [["events"]]} = Repo.query!("SELECT to_regclass('public.events')::text")

    assert %{rows: [["event_catalog"]]} =
             Repo.query!("SELECT to_regclass('public.event_catalog')::text")

    assert %{rows: [[nil]]} = Repo.query!("SELECT to_regclass('public.admin_audit_events')::text")
  end

  test "instance rows reject UPDATE, DELETE, and TRUNCATE" do
    event = Events.write_security!("security.admin.logout.v1")

    assert_raise Postgrex.Error, ~r/append-only/, fn ->
      Repo.query!("UPDATE events SET severity = 'error' WHERE id = $1", [event.id])
    end
  end

  test "instance rows reject DELETE" do
    event = Events.write_security!("security.admin.logout.v1")

    assert_raise Postgrex.Error, ~r/append-only/, fn ->
      Repo.query!("DELETE FROM events WHERE id = $1", [event.id])
    end
  end

  test "instance rows reject TRUNCATE" do
    Events.write_security!("security.admin.logout.v1")

    assert_raise Postgrex.Error, ~r/append-only/, fn ->
      Repo.query!("TRUNCATE events")
    end
  end

  test "database policy rejects weakening security catalog entries" do
    assert_raise Postgrex.Error, ~r/security event policy/, fn ->
      Repo.query!(
        "UPDATE event_catalog SET enabled = false WHERE key = 'security.admin.logout.v1'"
      )
    end
  end

  test "database policy rejects removing catalog entries" do
    assert_raise Postgrex.Error, ~r/cannot be deleted or truncated/, fn ->
      Repo.query!("DELETE FROM event_catalog WHERE key = 'security.admin.logout.v1'")
    end
  end

  test "database policy rejects details outside the pinned allowlist" do
    assert_raise Postgrex.Error, ~r/detail key is not allowed/, fn ->
      Repo.query!("""
      INSERT INTO events
        (event_key, event_class, details, occurred_at, retention_until, inserted_at)
      VALUES
        ('security.admin.logout.v1', 'security', '{"password":"secret"}', now(), now(), now())
      """)
    end
  end

  test "retention path never prunes a current row even with a future cutoff" do
    event = Events.write_security!("security.admin.logout.v1")

    assert Events.prune_expired!(~U[2126-01-01 00:00:00Z]) == 0
    assert Repo.get!(Event, event.id)
  end

  test "creates the account, subject, occurrence, and retention indexes" do
    %{rows: rows} =
      Repo.query!(
        "SELECT indexname FROM pg_indexes WHERE schemaname = 'public' AND tablename = 'events'"
      )

    indexes = MapSet.new(rows, fn [name] -> name end)

    for name <- ~w(
          events_actor_id_occurred_at_id_index
          events_owner_id_occurred_at_id_index
          events_subject_type_subject_id_occurred_at_id_index
          events_device_id_occurred_at_id_index
          events_run_id_occurred_at_id_index
          events_correlation_id_occurred_at_id_index
          events_severity_occurred_at_id_index
          events_occurred_at_id_index
          events_retention_until_index
        ) do
      assert MapSet.member?(indexes, name)
    end
  end
end
