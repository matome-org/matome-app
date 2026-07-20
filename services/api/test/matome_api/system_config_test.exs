defmodule MatomeApi.SystemConfigTest do
  use MatomeApi.DataCase, async: false

  import Ecto.Query

  alias MatomeApi.Admin
  alias MatomeApi.Events.Event
  alias MatomeApi.SystemConfig
  alias MatomeApi.SystemConfig.Policy
  alias MatomeApi.Storage.UploadPolicy

  @admin "admin@example.com"
  @ip "198.51.100.24"

  defp mutation_opts do
    [
      actor: %{email: @admin},
      otp_verified_at: System.os_time(:second),
      remote_ip: @ip
    ]
  end

  describe "v1 policy validation" do
    test "accepts only the closed, bounded non-secret schema" do
      document = Policy.default_document()

      assert {:ok, ^document} = Policy.validate(document)

      invalid = put_in(document, ["desired", "queue", "endpoint"], "https://secret.test")
      assert {:error, errors} = Policy.validate(invalid)
      assert "desired.queue.endpoint" in errors

      invalid = put_in(document, ["desired", "retry", "max_delay_seconds"], 0)
      assert {:error, errors} = Policy.validate(invalid)
      assert "desired.retry.max_delay_seconds" in errors

      invalid =
        document
        |> put_in(["desired", "retry", "base_delay_seconds"], 300)
        |> put_in(["desired", "retry", "max_delay_seconds"], 30)

      assert {:error, errors} = Policy.validate(invalid)
      assert "desired.retry.base_delay_seconds" in errors
    end

    test "database constraint validator rejects JSON strings masquerading as typed values" do
      invalid =
        Policy.default_document()
        |> put_in(["schema_version"], "1")
        |> Jason.encode!()

      assert %{rows: [[false]]} =
               Repo.query!("SELECT system_config_valid_v1($1::jsonb)", [invalid])

      invalid =
        Policy.default_document()
        |> put_in(["applied", "core_applied_at"], "2026-07-15")
        |> Jason.encode!()

      assert %{rows: [[false]]} =
               Repo.query!("SELECT system_config_valid_v1($1::jsonb)", [invalid])
    end
  end

  describe "singleton desired policy" do
    test "uses optimistic revision and records complete before/after policy atomically" do
      before = SystemConfig.get!()
      desired = put_in(before.document["desired"], ["queue", "paused"], true)

      assert {:ok, updated} =
               Admin.update_system_config(desired, before.document["revision"], mutation_opts())

      assert updated.document["revision"] == before.document["revision"] + 1
      assert updated.document["desired"]["queue"]["paused"]

      event =
        Repo.one!(
          from e in Event,
            where: e.event_key == "security.admin_config_changed.v2",
            order_by: [desc: e.id],
            limit: 1
        )

      assert event.actor_email == @admin
      assert event.remote_ip == @ip
      assert event.subject_type == "system_config"
      assert event.subject_id == "global"
      assert event.details["revision"] == updated.document["revision"]
      assert event.details["changed_keys"] == ["queue"]
      assert Jason.decode!(event.details["before"]) == before.document["desired"]
      assert Jason.decode!(event.details["after"]) == updated.document["desired"]

      assert {:error, :stale_revision} =
               Admin.update_system_config(before.document["desired"], 1, mutation_opts())

      assert SystemConfig.get!().document == updated.document
    end

    test "invalid, unauthorized, and unauditable changes never persist" do
      before = SystemConfig.get!()
      revision = before.document["revision"]
      invalid = put_in(before.document["desired"], ["uploads", "max_bytes"], -1)

      assert {:error, %Ecto.Changeset{}} =
               Admin.update_system_config(invalid, revision, mutation_opts())

      assert {:error, :forbidden} =
               Admin.update_system_config(
                 before.document["desired"],
                 revision,
                 Keyword.put(mutation_opts(), :actor, %{email: "stranger@example.com"})
               )

      changed = put_in(before.document["desired"], ["queue", "max_concurrency"], 3)

      assert {:error, {:audit_failed, _changeset}} =
               Admin.update_system_config(
                 changed,
                 revision,
                 Keyword.put(mutation_opts(), :remote_ip, String.duplicate("1", 65))
               )

      assert SystemConfig.get!().document == before.document
    end

    test "changing desired policy does not rewrite an existing processing snapshot" do
      before = SystemConfig.get!()
      snapshot_revision = before.document["revision"]
      desired = put_in(before.document["desired"], ["retry", "max_attempts"], 6)

      assert {:ok, _updated} =
               Admin.update_system_config(desired, snapshot_revision, mutation_opts())

      assert snapshot_revision < SystemConfig.current_revision()
      assert snapshot_revision == before.document["revision"]
    end

    test "accepted upload thresholds take effect without a restart" do
      before = SystemConfig.get!()

      desired =
        put_in(before.document["desired"], ["uploads", "single_max_bytes"], 10 * 1024 * 1024)

      assert {:ok, _updated} =
               Admin.update_system_config(desired, before.document["revision"], mutation_opts())

      assert UploadPolicy.mode_for("audio", 10 * 1024 * 1024) == :single
      assert UploadPolicy.mode_for("audio", 10 * 1024 * 1024 + 1) == :multipart
    end
  end
end
