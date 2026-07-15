defmodule MatomeApi.EventsTest do
  use MatomeApi.DataCase, async: true

  alias MatomeApi.Events
  alias MatomeApi.Events.{Event, EventCatalog}

  @repo_root Path.expand("../../../..", __DIR__)
  @contract_path Path.join(@repo_root, "contracts/v1/platform.json")

  @admin_keys ~w(
    security.admin.login_otp_requested.v1
    security.admin.login.v1
    security.admin.login_failed.v1
    security.admin.logout.v1
    security.admin.reauth.v1
    security.admin.session_revoked.v1
    security.admin.session_revoked.v2
    security.admin.space_updated.v1
    security.admin.space_updated.v2
    security.admin.space_member_added.v1
    security.admin.space_member_added.v2
    security.admin.space_member_revoked.v1
    security.admin.space_member_revoked.v2
    security.admin.space_lifecycle.v1
    security.admin.space_lifecycle.v2
    security.admin.sensitive_read.v1
  )

  @product_action_keys ~w(
    product.matome_added.v1
    product.matome_removed.v1
    product.matome_archived.v1
  )

  describe "catalog" do
    test "seeds stable entries for every current admin action" do
      assert Enum.all?(@admin_keys, &Repo.get(EventCatalog, &1))

      assert %EventCatalog{
               event_class: "security",
               enabled: true,
               locked: true,
               retention_days: 365
             } = Repo.get!(EventCatalog, "security.admin.login.v1")

      assert %EventCatalog{retention_days: 90} =
               Repo.get!(EventCatalog, "operational.work_transition.v1")

      assert %EventCatalog{retention_days: 30, enabled: false} =
               Repo.get!(EventCatalog, "product.capture_completed.v1")
    end

    test "seeds stable optional product keys for representative client actions" do
      assert Enum.all?(@product_action_keys, fn key ->
               match?(
                 %EventCatalog{event_class: "product", enabled: false, locked: false},
                 Repo.get(EventCatalog, key)
               )
             end)
    end

    test "database catalog detail policy matches the code allowlist" do
      assert Enum.all?(Repo.all(EventCatalog), fn catalog ->
               {:ok, detail_keys} = Events.detail_keys(catalog.key)
               Enum.sort(catalog.detail_keys) == Enum.sort(detail_keys)
             end)
    end

    test "seeded catalog exactly implements the platform contract" do
      contract_entries =
        @contract_path
        |> File.read!()
        |> Jason.decode!()
        |> get_in(["events", "catalog"])
        |> Map.new(fn entry ->
          {entry["catalog_key"],
           %{
             event_class: entry["event_class"],
             enabled: entry["enabled"],
             locked: entry["locked"],
             retention_days: entry["retention_days"],
             detail_keys: Enum.sort(entry["payload_allowlist"])
           }}
        end)

      database_entries =
        EventCatalog
        |> Repo.all()
        |> Map.new(fn entry ->
          {entry.key,
           %{
             event_class: entry.event_class,
             enabled: entry.enabled,
             locked: entry.locked,
             retention_days: entry.retention_days,
             detail_keys: Enum.sort(entry.detail_keys)
           }}
        end)

      assert database_entries == contract_entries
    end

    test "security entries cannot be disabled or shortened" do
      entry = Repo.get!(EventCatalog, "security.admin.login.v1")

      refute EventCatalog.changeset(entry, %{enabled: false}).valid?
      refute EventCatalog.changeset(entry, %{retention_days: 364}).valid?
    end

    test "catalog changes are atomic with a mandatory event and affect future writes" do
      before =
        Events.write_optional("operational.upload_completed.v1", %{
          occurred_at: ~U[2026-01-01 00:00:00Z],
          details: %{mode: "single", result: "ok"}
        })

      assert {:ok, %Event{}} = before

      assert {:ok, catalog} =
               MatomeApi.Admin.update_event_catalog(
                 "operational.upload_completed.v1",
                 %{retention_days: 120},
                 actor: %{email: "admin@example.com"},
                 otp_verified_at: System.os_time(:second),
                 remote_ip: "192.0.2.30"
               )

      assert catalog.retention_days == 120

      assert %Event{event_key: "security.event_catalog.changed.v2"} =
               Repo.one!(
                 from e in Event,
                   where: e.event_key == "security.event_catalog.changed.v2"
               )

      assert {:ok, after_event} =
               Events.write_optional("operational.upload_completed.v1", %{
                 occurred_at: ~U[2026-01-01 00:00:00Z],
                 details: %{mode: "multipart", result: "ok"}
               })

      {:ok, before_event} = before
      assert DateTime.diff(before_event.retention_until, before_event.occurred_at, :day) == 90
      assert DateTime.diff(after_event.retention_until, after_event.occurred_at, :day) == 120
    end
  end

  describe "writes" do
    test "security writes fail closed and persist indexed dimensions" do
      event =
        Events.write_security!("security.admin.login.v1", %{
          actor_email: "admin@example.com",
          owner_id: nil,
          subject_type: "admin_session",
          subject_id: "session-42",
          correlation_id: "request-7",
          severity: "info",
          occurred_at: ~U[2026-01-01 00:00:00Z],
          details: %{method: "email_otp", result: "verified"}
        })

      assert %Event{
               event_class: "security",
               actor_email: "admin@example.com",
               subject_type: "admin_session",
               subject_id: "session-42",
               correlation_id: "request-7",
               severity: "info"
             } = event

      assert DateTime.diff(event.retention_until, event.occurred_at, :day) == 365
    end

    test "security writes raise for unknown details" do
      assert_raise Ecto.InvalidChangesetError, fn ->
        Events.write_security!("security.admin.login.v1", %{
          details: %{password: "must-not-be-stored"}
        })
      end

      refute Repo.exists?(from e in Event, where: e.event_key == "security.admin.login.v1")
    end

    test "transactional security helper rejects non-security catalog keys" do
      assert {:error, {:event, :security_policy}, :security_event_required, %{}} =
               Ecto.Multi.new()
               |> Events.put_security(:event, "operational.upload_completed.v1", %{
                 details: %{mode: "single", result: "ok"}
               })
               |> Repo.transaction()

      refute Repo.exists?(
               from e in Event,
                 where: e.event_key == "operational.upload_completed.v1"
             )
    end

    test "disabled optional events insert nothing" do
      assert {:ok, :disabled} =
               Events.write_optional("product.capture_completed.v1", %{
                 details: %{input_kind: "audio", result: "ok"}
               })

      refute Repo.exists?(from e in Event, where: e.event_key == "product.capture_completed.v1")
    end

    test "optional invalid events are dropped without raising" do
      assert {:error, :invalid_event} =
               Events.write_optional("operational.upload_completed.v1", %{
                 details: %{authorization: "Bearer secret"}
               })

      refute Repo.exists?(
               from e in Event,
                 where: e.event_key == "operational.upload_completed.v1"
             )
    end

    test "details reject nested and oversized values" do
      assert {:error, :invalid_event} =
               Events.write_optional("operational.processing_completed.v1", %{
                 details: %{output_types: [%{type: "summary"}]}
               })

      assert {:error, :invalid_event} =
               Events.write_optional("operational.processing_completed.v1", %{
                 details: %{error_code: String.duplicate("x", 513)}
               })
    end
  end

  describe "retention" do
    test "only the privileged retention path removes expired rows" do
      assert {:ok, expired} =
               Events.write_optional("operational.upload_completed.v1", %{
                 occurred_at: ~U[2020-01-01 00:00:00Z],
                 details: %{mode: "single", result: "ok"}
               })

      assert {:ok, current} =
               Events.write_optional("operational.upload_completed.v1", %{
                 occurred_at: DateTime.utc_now(),
                 details: %{mode: "single", result: "ok"}
               })

      assert_raise Postgrex.Error, ~r/append-only/, fn ->
        Repo.query!("DELETE FROM events WHERE id = $1", [expired.id])
      end

      assert Events.prune_expired!() == 1
      refute Repo.get(Event, expired.id)
      assert Repo.get(Event, current.id)
    end
  end

  describe "cursor pagination" do
    test "uses occurred_at and id as a stable descending cursor" do
      occurred_at = ~U[2026-01-01 00:00:00Z]

      ids =
        for correlation_id <- ~w(one two three) do
          Events.write_security!("security.admin.logout.v1", %{
            correlation_id: correlation_id,
            occurred_at: occurred_at
          }).id
        end

      first = Events.list_events(limit: 2, event_class: "security")
      second = Events.list_events(limit: 2, event_class: "security", after: first.next_cursor)

      assert Enum.map(first.entries, & &1.id) == ids |> Enum.reverse() |> Enum.take(2)
      assert Enum.map(second.entries, & &1.id) == [hd(ids)]
      assert first.next_cursor
      assert second.next_cursor == nil
    end

    test "filters account and subject dimensions before paginating" do
      Events.write_security!("security.admin.session_revoked.v1", %{
        subject_type: "session",
        subject_id: "wanted",
        correlation_id: "matching"
      })

      Events.write_security!("security.admin.session_revoked.v1", %{
        subject_type: "session",
        subject_id: "other",
        correlation_id: "not-matching"
      })

      page = Events.list_events(subject_type: "session", subject_id: "wanted")

      assert [%Event{correlation_id: "matching"}] = page.entries
    end

    test "applies every indexed timeline dimension before paginating" do
      run_id = Ecto.UUID.generate()

      Events.write_security!("security.admin.session_revoked.v1", %{
        actor_id: 10,
        actor_email: "actor@example.com",
        owner_id: 20,
        subject_type: "session",
        subject_id: "subject-30",
        device_id: 40,
        run_id: run_id,
        severity: "warning",
        occurred_at: ~U[2026-07-15 10:00:00Z],
        correlation_id: "all-dimensions"
      })

      Events.write_security!("security.admin.session_revoked.v1", %{
        actor_id: 11,
        owner_id: 21,
        subject_type: "session",
        subject_id: "other",
        device_id: 41,
        severity: "info",
        occurred_at: ~U[2026-07-15 10:00:00Z],
        correlation_id: "distractor"
      })

      page =
        Events.list_events(
          event_class: "security",
          event_key: "security.admin.session_revoked.v1",
          actor_id: 10,
          actor_email: "actor@example.com",
          owner_id: 20,
          subject_type: "session",
          subject_id: "subject-30",
          device_id: 40,
          run_id: run_id,
          severity: "warning",
          since: ~U[2026-07-15 09:00:00Z],
          until: ~U[2026-07-15 11:00:00Z]
        )

      assert [%Event{correlation_id: "all-dimensions"}] = page.entries
    end
  end
end
