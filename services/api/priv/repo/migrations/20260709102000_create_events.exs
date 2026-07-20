defmodule MatomeApi.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  @moduledoc """
  W3 #2038 canonical event store. `events` is the only instance table;
  `event_catalog` is mutable collection policy. Event rows snapshot class and
  expiry at insert, reject rewrites, and can be deleted only by the bounded
  security-definer retention function.
  """

  def up do
    create table(:event_catalog, primary_key: false) do
      add :key, :string, primary_key: true
      add :event_class, :string, null: false
      add :enabled, :boolean, null: false
      add :description, :text, null: false
      add :retention_days, :integer, null: false
      add :locked, :boolean, null: false
      add :detail_keys, {:array, :string}, null: false, default: []

      timestamps(type: :utc_datetime_usec)
    end

    create constraint(:event_catalog, :event_catalog_key_format,
             check: "key ~ '^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+\\.v[1-9][0-9]*$'"
           )

    create constraint(:event_catalog, :event_catalog_class,
             check: "event_class IN ('security', 'operational', 'product')"
           )

    create constraint(:event_catalog, :event_catalog_retention_floor,
             check: """
             (event_class = 'security' AND retention_days >= 365) OR
             (event_class = 'operational' AND retention_days >= 90) OR
             (event_class = 'product' AND retention_days >= 30)
             """
           )

    create constraint(:event_catalog, :event_catalog_security_policy,
             check: "event_class <> 'security' OR (locked AND enabled)"
           )

    create constraint(:event_catalog, :event_catalog_detail_key_limit,
             check: "cardinality(detail_keys) <= 32"
           )

    execute """
    CREATE FUNCTION event_catalog_protect_policy() RETURNS trigger AS $$
    BEGIN
      IF NEW.key IS DISTINCT FROM OLD.key OR
         NEW.event_class IS DISTINCT FROM OLD.event_class OR
         NEW.locked IS DISTINCT FROM OLD.locked OR
         NEW.detail_keys IS DISTINCT FROM OLD.detail_keys THEN
        RAISE EXCEPTION 'event catalog identity and detail policy are immutable';
      END IF;

      IF OLD.event_class = 'security' AND
         (NOT NEW.enabled OR NEW.retention_days < 365) THEN
        RAISE EXCEPTION 'security event policy cannot be disabled or shortened below 365 days';
      END IF;

      IF OLD.locked AND NOT NEW.enabled THEN
        RAISE EXCEPTION 'locked event policy cannot be disabled';
      END IF;

      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql
    """

    execute """
    CREATE TRIGGER event_catalog_policy_guard
    BEFORE UPDATE ON event_catalog
    FOR EACH ROW EXECUTE FUNCTION event_catalog_protect_policy()
    """

    execute """
    CREATE FUNCTION event_catalog_prevent_removal() RETURNS trigger AS $$
    BEGIN
      RAISE EXCEPTION 'event catalog entries cannot be deleted or truncated';
    END;
    $$ LANGUAGE plpgsql
    """

    execute """
    CREATE TRIGGER event_catalog_no_delete
    BEFORE DELETE ON event_catalog
    FOR EACH ROW EXECUTE FUNCTION event_catalog_prevent_removal()
    """

    execute """
    CREATE TRIGGER event_catalog_no_truncate
    BEFORE TRUNCATE ON event_catalog
    FOR EACH STATEMENT EXECUTE FUNCTION event_catalog_prevent_removal()
    """

    create table(:events) do
      add :event_key,
          references(:event_catalog,
            column: :key,
            type: :string,
            on_update: :restrict,
            on_delete: :restrict
          ),
          null: false

      add :event_class, :string, null: false
      add :severity, :string, null: false, default: "info"
      add :actor_id, :bigint
      add :actor_email, :string
      add :owner_id, :bigint
      add :subject_type, :string
      add :subject_id, :string
      # `devices` is created by a later migration; this remains an indexed
      # scalar dimension rather than introducing a migration-order dependency.
      add :device_id, :bigint
      add :run_id, :uuid
      add :correlation_id, :string
      add :source_type, :string, null: false, default: "core"
      add :source_id, :string, null: false, default: "core"
      add :remote_ip, :string
      add :details, :map, null: false, default: %{}
      add :occurred_at, :utc_datetime_usec, null: false
      add :retention_until, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create constraint(:events, :events_severity,
             check: "severity IN ('info', 'warning', 'error', 'critical')"
           )

    create constraint(:events, :events_subject_pair,
             check: "(subject_type IS NULL) = (subject_id IS NULL)"
           )

    create index(:events, [:event_key, :occurred_at, :id])
    create index(:events, [:event_class, :occurred_at, :id])
    create index(:events, [:actor_id, :occurred_at, :id])
    create index(:events, [:actor_email, :occurred_at, :id])
    create index(:events, [:owner_id, :occurred_at, :id])
    create index(:events, [:subject_type, :subject_id, :occurred_at, :id])
    create index(:events, [:device_id, :occurred_at, :id])
    create index(:events, [:run_id, :occurred_at, :id])
    create index(:events, [:correlation_id, :occurred_at, :id])
    create index(:events, [:severity, :occurred_at, :id])
    create index(:events, [:occurred_at, :id])
    create index(:events, [:retention_until])

    seed_catalog()

    execute """
    CREATE FUNCTION events_apply_catalog() RETURNS trigger AS $$
    DECLARE
      catalog event_catalog%ROWTYPE;
      detail_key text;
    BEGIN
      SELECT * INTO catalog FROM event_catalog WHERE key = NEW.event_key;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'unknown event catalog key: %', NEW.event_key;
      END IF;

      IF NOT catalog.enabled THEN
        RAISE EXCEPTION 'event catalog key is disabled: %', NEW.event_key;
      END IF;

      NEW.event_class := catalog.event_class;
      NEW.occurred_at := COALESCE(NEW.occurred_at, clock_timestamp());
      NEW.retention_until := NEW.occurred_at + make_interval(days => catalog.retention_days);
      NEW.details := COALESCE(NEW.details, '{}'::jsonb);

      IF jsonb_typeof(NEW.details) <> 'object' THEN
        RAISE EXCEPTION 'event details must be a JSON object';
      END IF;

      IF octet_length(NEW.details::text) > 4096 THEN
        RAISE EXCEPTION 'event details exceed 4096 bytes';
      END IF;

      FOR detail_key IN SELECT jsonb_object_keys(NEW.details)
      LOOP
        IF NOT detail_key = ANY(catalog.detail_keys) THEN
          RAISE EXCEPTION 'event detail key is not allowed: %', detail_key;
        END IF;
      END LOOP;

      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql
    """

    execute """
    CREATE TRIGGER events_catalog_guard
    BEFORE INSERT ON events
    FOR EACH ROW EXECUTE FUNCTION events_apply_catalog()
    """

    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'matome_event_retention_pruner') THEN
        CREATE ROLE matome_event_retention_pruner NOLOGIN NOINHERIT;
      END IF;
    END
    $$
    """

    execute "GRANT USAGE ON SCHEMA public TO matome_event_retention_pruner"
    execute "GRANT SELECT, DELETE ON events TO matome_event_retention_pruner"

    execute """
    CREATE FUNCTION prune_expired_events(p_cutoff timestamptz DEFAULT clock_timestamp())
    RETURNS bigint AS $$
      WITH deleted AS (
        DELETE FROM public.events
        WHERE retention_until <= LEAST(p_cutoff, clock_timestamp())
        RETURNING id
      )
      SELECT count(*)::bigint FROM deleted
    $$ LANGUAGE sql
       SECURITY DEFINER
       SET search_path = pg_catalog, public
    """

    execute "ALTER FUNCTION prune_expired_events(timestamptz) OWNER TO matome_event_retention_pruner"
    execute "REVOKE ALL ON FUNCTION prune_expired_events(timestamptz) FROM PUBLIC"

    execute """
    DO $$
    BEGIN
      EXECUTE format(
        'GRANT EXECUTE ON FUNCTION prune_expired_events(timestamptz) TO %I',
        current_user
      );
    END
    $$
    """

    execute "REVOKE UPDATE, DELETE, TRUNCATE ON events FROM PUBLIC"

    execute """
    CREATE FUNCTION events_append_only() RETURNS trigger AS $$
    BEGIN
      IF TG_OP = 'DELETE' AND
         current_user = 'matome_event_retention_pruner' AND
         OLD.retention_until <= clock_timestamp() THEN
        RETURN OLD;
      END IF;

      RAISE EXCEPTION 'events is append-only';
    END;
    $$ LANGUAGE plpgsql
    """

    execute """
    CREATE TRIGGER events_no_rewrite
    BEFORE UPDATE OR DELETE ON events
    FOR EACH ROW EXECUTE FUNCTION events_append_only()
    """

    execute """
    CREATE TRIGGER events_no_truncate
    BEFORE TRUNCATE ON events
    FOR EACH STATEMENT EXECUTE FUNCTION events_append_only()
    """
  end

  def down do
    execute "DROP TRIGGER events_no_truncate ON events"
    execute "DROP TRIGGER events_no_rewrite ON events"
    execute "DROP FUNCTION events_append_only()"

    execute """
    DO $$
    BEGIN
      EXECUTE format(
        'ALTER FUNCTION prune_expired_events(timestamptz) OWNER TO %I',
        current_user
      );
    END
    $$
    """

    execute "DROP FUNCTION prune_expired_events(timestamptz)"
    execute "DROP TRIGGER events_catalog_guard ON events"
    execute "DROP FUNCTION events_apply_catalog()"

    drop table(:events)

    execute "DROP TRIGGER event_catalog_no_truncate ON event_catalog"
    execute "DROP TRIGGER event_catalog_no_delete ON event_catalog"
    execute "DROP FUNCTION event_catalog_prevent_removal()"
    execute "DROP TRIGGER event_catalog_policy_guard ON event_catalog"
    execute "DROP FUNCTION event_catalog_protect_policy()"

    drop table(:event_catalog)
  end

  defp seed_catalog do
    execute """
    INSERT INTO event_catalog
      (key, event_class, enabled, description, retention_days, locked, detail_keys,
       inserted_at, updated_at)
    VALUES
      ('security.event_catalog.changed.v1', 'security', true,
       'A collection policy changed.', 365, true, ARRAY['changed_fields'], now(), now()),
      ('security.admin.login_otp_requested.v1', 'security', true,
       'An administrator requested a login code.', 365, true, ARRAY[]::varchar[], now(), now()),
      ('security.admin.login.v1', 'security', true,
       'An administrator authenticated.', 365, true, ARRAY['method', 'result', 'via'], now(), now()),
      ('security.admin.login_failed.v1', 'security', true,
       'An administrator authentication attempt failed.', 365, true,
       ARRAY['method', 'reason', 'result'], now(), now()),
      ('security.admin.logout.v1', 'security', true,
       'An administrator ended a session.', 365, true, ARRAY[]::varchar[], now(), now()),
      ('security.admin.reauth.v1', 'security', true,
       'An administrator completed sensitive-action reauthentication.', 365, true,
       ARRAY['method', 'result'], now(), now()),
      ('security.admin.session_revoked.v1', 'security', true,
       'An administrator revoked a user session.', 365, true, ARRAY[]::varchar[], now(), now()),
      ('security.admin.space_updated.v1', 'security', true,
       'An administrator changed Space policy.', 365, true, ARRAY['changed_keys'], now(), now()),
      ('security.admin.space_member_added.v1', 'security', true,
       'An administrator added a Space member.', 365, true,
       ARRAY['workspace_id', 'user_id', 'role'], now(), now()),
      ('security.admin.space_member_revoked.v1', 'security', true,
       'An administrator revoked a Space member.', 365, true,
       ARRAY['workspace_id', 'user_id'], now(), now()),
      ('security.admin.space_lifecycle.v1', 'security', true,
       'An administrator changed Space lifecycle state.', 365, true, ARRAY['to_status'], now(), now()),
      ('security.admin_auth_verified.v1', 'security', true,
       'A privileged authentication check completed.', 365, true, ARRAY['method', 'result'], now(), now()),
      ('security.admin_config_changed.v1', 'security', true,
       'An administrator changed system configuration.', 365, true,
       ARRAY['revision', 'changed_keys', 'result'], now(), now()),
      ('operational.work_transition.v1', 'operational', true,
       'A durable work item changed state.', 90, true,
       ARRAY['operation', 'input_kind', 'from_state', 'to_state', 'attempt',
             'duration_ms', 'error_code'], now(), now()),
      ('operational.upload_completed.v1', 'operational', true,
       'An upload attempt completed.', 90, false,
       ARRAY['mode', 'byte_size', 'part_count', 'duration_ms', 'result', 'error_code'],
       now(), now()),
      ('operational.processing_completed.v1', 'operational', true,
       'A processing attempt completed.', 90, false,
       ARRAY['input_kind', 'output_types', 'duration_ms', 'attempt', 'result', 'error_code'],
       now(), now()),
      ('product.capture_completed.v1', 'product', false,
       'An opted-in aggregate capture event.', 30, false,
       ARRAY['input_kind', 'duration_bucket', 'size_bucket', 'platform', 'result'],
       now(), now()),
      ('product.local_space_aggregate.v1', 'product', false,
       'An opted-in local Space aggregate.', 30, false,
       ARRAY['period', 'item_count_bucket', 'byte_size_bucket', 'platform'], now(), now())
    """
  end
end
