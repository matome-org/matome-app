defmodule MatomeApi.Repo.AdminAuditEventsImmutabilityTest do
  @moduledoc """
  W3 #1871 acceptance — `admin_audit_events` is proven append-only AT THE
  DATABASE, as the app DB role: UPDATE, DELETE, and TRUNCATE must all be
  denied by the `admin_audit_events_no_rewrite` / `_no_truncate` triggers.

  Raw SQL on purpose: the guarantee under test is about what the connected
  application role can do to the table, not about any Ecto-level convention.
  One rewrite attempt per test — the raised DB error aborts the sandboxed
  transaction, so a second statement in the same test would only see
  "transaction is aborted" noise.
  """
  use MatomeApi.DataCase, async: true

  defp insert_event! do
    %{rows: [[id]]} =
      Repo.query!(
        """
        INSERT INTO admin_audit_events (actor_email, action, metadata, inserted_at)
        VALUES ('admin@example.com', 'admin.login', '{}', now())
        RETURNING id
        """,
        []
      )

    id
  end

  test "INSERT is allowed (the trail can be written)" do
    assert is_integer(insert_event!())
  end

  test "UPDATE is denied at the DB level" do
    id = insert_event!()

    assert_raise Postgrex.Error, ~r/append-only/, fn ->
      Repo.query!("UPDATE admin_audit_events SET action = 'tampered' WHERE id = $1", [id])
    end
  end

  test "DELETE is denied at the DB level" do
    id = insert_event!()

    assert_raise Postgrex.Error, ~r/append-only/, fn ->
      Repo.query!("DELETE FROM admin_audit_events WHERE id = $1", [id])
    end
  end

  test "TRUNCATE is denied at the DB level" do
    insert_event!()

    assert_raise Postgrex.Error, ~r/append-only/, fn ->
      Repo.query!("TRUNCATE admin_audit_events", [])
    end
  end
end
