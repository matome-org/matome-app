defmodule MatomeApi.Repo.Migrations.CreateSystemConfig do
  use Ecto.Migration

  def up do
    execute """
    CREATE FUNCTION system_config_valid_v1(document jsonb)
    RETURNS boolean
    LANGUAGE plpgsql
    IMMUTABLE
    STRICT
    AS $$
    DECLARE
      desired jsonb;
      queue_policy jsonb;
      retry_policy jsonb;
      upload_policy jsonb;
      ai_policy jsonb;
      client_policy jsonb;
      applied jsonb;
      lease_seconds bigint;
      queue_concurrency bigint;
      snapshot_interval bigint;
      max_attempts bigint;
      base_delay bigint;
      max_delay bigint;
      single_max bigint;
      part_bytes bigint;
      max_bytes bigint;
      job_timeout bigint;
      poll_interval bigint;
    BEGIN
      IF jsonb_typeof(document) <> 'object' OR
         (SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(document) AS t(k)) <>
           ARRAY['applied', 'desired', 'revision', 'schema_version'] THEN
        RETURN false;
      END IF;

      IF jsonb_typeof(document->'schema_version') <> 'number' OR
         document->>'schema_version' <> '1' OR
         jsonb_typeof(document->'revision') <> 'number' OR
         document->>'revision' !~ '^[1-9][0-9]*$' THEN
        RETURN false;
      END IF;

      desired := document->'desired';
      applied := document->'applied';

      IF jsonb_typeof(desired) <> 'object' OR
         (SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(desired) AS t(k)) <>
           ARRAY['ai', 'clients', 'queue', 'retry', 'uploads'] OR
         jsonb_typeof(applied) <> 'object' OR
         (SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(applied) AS t(k)) <>
           ARRAY['core_applied_at', 'core_revision'] THEN
        RETURN false;
      END IF;

      queue_policy := desired->'queue';
      retry_policy := desired->'retry';
      upload_policy := desired->'uploads';
      ai_policy := desired->'ai';
      client_policy := desired->'clients';

      IF jsonb_typeof(queue_policy) <> 'object' OR
         (SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(queue_policy) AS t(k)) <>
           ARRAY['lease_seconds', 'max_concurrency', 'paused', 'snapshot_interval_seconds'] OR
         jsonb_typeof(retry_policy) <> 'object' OR
         (SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(retry_policy) AS t(k)) <>
           ARRAY['base_delay_seconds', 'max_attempts', 'max_delay_seconds'] OR
         jsonb_typeof(upload_policy) <> 'object' OR
         (SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(upload_policy) AS t(k)) <>
           ARRAY['max_bytes', 'multipart_part_bytes', 'single_max_bytes'] OR
         jsonb_typeof(ai_policy) <> 'object' OR
         (SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(ai_policy) AS t(k)) <>
           ARRAY['enabled_input_kinds', 'job_timeout_seconds'] OR
         jsonb_typeof(client_policy) <> 'object' OR
         (SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(client_policy) AS t(k)) <>
           ARRAY['minimum_wire_version', 'poll_interval_seconds'] THEN
        RETURN false;
      END IF;

      IF jsonb_typeof(queue_policy->'paused') <> 'boolean' OR
         jsonb_typeof(queue_policy->'lease_seconds') <> 'number' OR
         queue_policy->>'lease_seconds' !~ '^[0-9]+$' OR
         jsonb_typeof(queue_policy->'max_concurrency') <> 'number' OR
         queue_policy->>'max_concurrency' !~ '^[0-9]+$' OR
         jsonb_typeof(queue_policy->'snapshot_interval_seconds') <> 'number' OR
         queue_policy->>'snapshot_interval_seconds' !~ '^[0-9]+$' OR
         jsonb_typeof(retry_policy->'max_attempts') <> 'number' OR
         retry_policy->>'max_attempts' !~ '^[0-9]+$' OR
         jsonb_typeof(retry_policy->'base_delay_seconds') <> 'number' OR
         retry_policy->>'base_delay_seconds' !~ '^[0-9]+$' OR
         jsonb_typeof(retry_policy->'max_delay_seconds') <> 'number' OR
         retry_policy->>'max_delay_seconds' !~ '^[0-9]+$' OR
         jsonb_typeof(upload_policy->'single_max_bytes') <> 'number' OR
         upload_policy->>'single_max_bytes' !~ '^[0-9]+$' OR
         jsonb_typeof(upload_policy->'multipart_part_bytes') <> 'number' OR
         upload_policy->>'multipart_part_bytes' !~ '^[0-9]+$' OR
         jsonb_typeof(upload_policy->'max_bytes') <> 'number' OR
         upload_policy->>'max_bytes' !~ '^[0-9]+$' OR
         jsonb_typeof(ai_policy->'job_timeout_seconds') <> 'number' OR
         ai_policy->>'job_timeout_seconds' !~ '^[0-9]+$' OR
         jsonb_typeof(client_policy->'poll_interval_seconds') <> 'number' OR
         client_policy->>'poll_interval_seconds' !~ '^[0-9]+$' OR
         jsonb_typeof(client_policy->'minimum_wire_version') <> 'string' OR
         client_policy->>'minimum_wire_version' !~ '^[1-9][0-9]*$' OR
         jsonb_typeof(applied->'core_revision') <> 'number' OR
         applied->>'core_revision' !~ '^[0-9]+$' THEN
        RETURN false;
      END IF;

      lease_seconds := (queue_policy->>'lease_seconds')::bigint;
      queue_concurrency := (queue_policy->>'max_concurrency')::bigint;
      snapshot_interval := (queue_policy->>'snapshot_interval_seconds')::bigint;
      max_attempts := (retry_policy->>'max_attempts')::bigint;
      base_delay := (retry_policy->>'base_delay_seconds')::bigint;
      max_delay := (retry_policy->>'max_delay_seconds')::bigint;
      single_max := (upload_policy->>'single_max_bytes')::bigint;
      part_bytes := (upload_policy->>'multipart_part_bytes')::bigint;
      max_bytes := (upload_policy->>'max_bytes')::bigint;
      job_timeout := (ai_policy->>'job_timeout_seconds')::bigint;
      poll_interval := (client_policy->>'poll_interval_seconds')::bigint;

      IF lease_seconds NOT BETWEEN 15 AND 3600 OR
         queue_concurrency NOT BETWEEN 1 AND 16 OR
         snapshot_interval NOT BETWEEN 60 AND 86400 OR
         max_attempts NOT BETWEEN 1 AND 20 OR
         base_delay NOT BETWEEN 1 AND 3600 OR
         max_delay NOT BETWEEN 1 AND 86400 OR
         base_delay > max_delay OR
         single_max NOT BETWEEN 1 AND 2147483648 OR
         part_bytes NOT BETWEEN 5242880 AND 536870912 OR
         max_bytes NOT BETWEEN 5242880 AND 2147483648 OR
         single_max > max_bytes OR
         part_bytes > max_bytes OR
         job_timeout NOT BETWEEN 30 AND 86400 OR
         poll_interval NOT BETWEEN 1 AND 3600 OR
         (applied->>'core_revision')::bigint > (document->>'revision')::bigint THEN
        RETURN false;
      END IF;

      IF jsonb_typeof(ai_policy->'enabled_input_kinds') <> 'array' OR
         EXISTS (
           SELECT 1
           FROM jsonb_array_elements_text(ai_policy->'enabled_input_kinds') AS kind
           WHERE kind NOT IN ('audio', 'image', 'document', 'text')
         ) OR
         jsonb_array_length(ai_policy->'enabled_input_kinds') <>
           (SELECT count(DISTINCT kind) FROM jsonb_array_elements_text(ai_policy->'enabled_input_kinds') AS kind) OR
         NOT (
           jsonb_typeof(applied->'core_applied_at') = 'null' OR
           jsonb_typeof(applied->'core_applied_at') = 'string'
         ) THEN
        RETURN false;
      END IF;

      IF jsonb_typeof(applied->'core_applied_at') = 'string' THEN
        IF applied->>'core_applied_at' !~
             '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$' THEN
          RETURN false;
        END IF;

        PERFORM (applied->>'core_applied_at')::timestamptz;
      END IF;

      RETURN true;
    EXCEPTION WHEN others THEN
      RETURN false;
    END;
    $$
    """

    create table(:system_configs, primary_key: false) do
      add :key, :text, primary_key: true
      add :document, :map, null: false
      timestamps(type: :utc_datetime)
    end

    create constraint(:system_configs, :system_configs_global_singleton, check: "key = 'global'")

    create constraint(:system_configs, :system_configs_document_v1,
             check: "system_config_valid_v1(document)"
           )

    execute """
    INSERT INTO system_configs (key, document, inserted_at, updated_at)
    VALUES (
      'global',
      '{
        "schema_version": 1,
        "revision": 1,
        "desired": {
          "queue": {
            "paused": false,
            "lease_seconds": 120,
            "max_concurrency": 2,
            "snapshot_interval_seconds": 900
          },
          "retry": {
            "max_attempts": 5,
            "base_delay_seconds": 2,
            "max_delay_seconds": 300
          },
          "uploads": {
            "single_max_bytes": 26214400,
            "multipart_part_bytes": 16777216,
            "max_bytes": 2147483648
          },
          "ai": {
            "enabled_input_kinds": ["audio", "image", "document", "text"],
            "job_timeout_seconds": 1800
          },
          "clients": {
            "minimum_wire_version": "1",
            "poll_interval_seconds": 2
          }
        },
        "applied": {
          "core_revision": 0,
          "core_applied_at": null
        }
      }'::jsonb,
      now(),
      now()
    )
    """

    execute """
    INSERT INTO event_catalog
      (key, event_class, enabled, description, retention_days, locked, detail_keys,
       inserted_at, updated_at)
    VALUES
      ('security.admin_config_changed.v2', 'security', true,
       'An administrator changed non-secret system policy with before and after state.',
       365, true, ARRAY['revision', 'changed_keys', 'before', 'after', 'result'], now(), now())
    """
  end

  # The security event identity and singleton revision history are append-only.
  def down, do: raise("system config v1 is irreversible")
end
