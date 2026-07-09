defmodule MatomeApi.Repo.Migrations.CreateAdminAuditEvents do
  use Ecto.Migration

  @moduledoc """
  W3 #1871 (plan p2-core-backoffice §9.1) — immutable admin audit trail.

  Append-only is enforced AT THE DATABASE, not by convention: a plain table
  the admin (or a compromised app) can rewrite is audit theatre.

  Two layers:

  1. `REVOKE UPDATE, DELETE, TRUNCATE ... FROM PUBLIC` — denies every
     non-owner role by default.
  2. A `BEFORE UPDATE OR DELETE` (+ statement-level `TRUNCATE`) trigger that
     unconditionally raises — this is the layer that also binds the table
     OWNER (grants never restrict the owner; triggers fire for everyone).
     Rewriting history would require `ALTER TABLE ... DISABLE TRIGGER` DDL,
     which is a far louder, separately-auditable act than an UPDATE.

  `actor_email` is snapshotted (not just the FK) so the trail stays readable
  even if the user row is later deleted (`nilify_all`). No `updated_at`
  column on purpose — rows are never updated.
  """

  def up do
    create table(:admin_audit_events) do
      add :actor_id, references(:users, on_delete: :nilify_all)
      add :actor_email, :string
      add :action, :string, null: false
      add :metadata, :map, null: false, default: %{}
      add :remote_ip, :string

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:admin_audit_events, [:actor_id])
    create index(:admin_audit_events, [:inserted_at])

    execute "REVOKE UPDATE, DELETE, TRUNCATE ON admin_audit_events FROM PUBLIC"

    execute """
    CREATE FUNCTION admin_audit_events_immutable() RETURNS trigger AS $$
    BEGIN
      RAISE EXCEPTION 'admin_audit_events is append-only';
    END;
    $$ LANGUAGE plpgsql
    """

    execute """
    CREATE TRIGGER admin_audit_events_no_rewrite
    BEFORE UPDATE OR DELETE ON admin_audit_events
    FOR EACH ROW EXECUTE FUNCTION admin_audit_events_immutable()
    """

    execute """
    CREATE TRIGGER admin_audit_events_no_truncate
    BEFORE TRUNCATE ON admin_audit_events
    FOR EACH STATEMENT EXECUTE FUNCTION admin_audit_events_immutable()
    """
  end

  def down do
    execute "DROP TRIGGER admin_audit_events_no_truncate ON admin_audit_events"
    execute "DROP TRIGGER admin_audit_events_no_rewrite ON admin_audit_events"
    execute "DROP FUNCTION admin_audit_events_immutable()"

    drop table(:admin_audit_events)
  end
end
