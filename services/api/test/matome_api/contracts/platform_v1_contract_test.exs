defmodule MatomeApi.Contracts.PlatformV1ContractTest do
  use ExUnit.Case, async: true

  @repo_root Path.expand("../../../../..", __DIR__)
  @contract_path Path.join(@repo_root, "contracts/v1/platform.json")
  @fixtures_path Path.join(@repo_root, "contracts/v1/fixtures/canonical.json")
  @mismatches_path Path.join(@repo_root, "contracts/v1/fixtures/known-mismatches.json")
  @system_config_schema_path Path.join(@repo_root, "contracts/v1/system-config.schema.json")

  test "freezes the local-first work lifecycle and ownership boundaries" do
    contract = read_json!(@contract_path)
    work = contract["work"]

    assert contract["version"] == "1.0.0"
    assert contract["wire_version"] == "1"

    assert work["states"] == ~w(
             local_saved
             work_queued
             parent_item_reconciled
             uploading
             uploaded
             processing_queued
             processing
             succeeded
             failed
           )

    states = MapSet.new(work["states"])
    transitions = work["legal_transitions"]
    assert MapSet.new(Map.keys(transitions)) == states

    assert Enum.all?(transitions, fn {_from, targets} ->
             MapSet.subset?(MapSet.new(targets), states)
           end)

    assert work["authorities"] |> Map.keys() |> Enum.sort() == ~w(core drift oban)
    assert work["lease"]["expiry_action"] == "requeue_if_run_is_current"
    assert work["retry"]["strategy"] == "exponential_full_jitter"
    assert work["retry"]["manual_retry_creates_new_run"]

    assert work["stale_run"]["accept_when"] ==
             "run_id_and_input_revision_match_current"

    assert work["upload_only_completion"] == %{
             "processing_state" => "not_requested",
             "upload_state" => "uploaded",
             "work_state" => "succeeded"
           }
  end

  test "pins upload, AI, event, and system configuration envelopes" do
    contract = read_json!(@contract_path)
    fixtures = read_json!(@fixtures_path)
    schema = read_json!(@system_config_schema_path)

    assert contract["upload"]["modes"] == ~w(single multipart)
    assert contract["upload"]["operations"] == ~w(request complete abort)

    for mode <- ~w(single multipart) do
      fixture = fixtures["uploads"][mode]
      assert fixture["response"]["upload"]["mode"] == mode

      assert Map.keys(fixture) |> Enum.sort() ==
               ~w(abort_request abort_response complete_request complete_response request response)
    end

    assert fixtures["uploads"]["multipart"]["complete_request"]["parts"]
           |> Enum.map(& &1["part_number"]) == [1, 2]

    assert contract["ai"]["input_kinds"] == ~w(audio image document text)
    assert contract["ai"]["callback_statuses"] == ~w(done failed)
    assert contract["ai"]["auth"] == "bearer_service_token"
    assert Map.keys(fixtures["ai"]["jobs"]) |> Enum.sort() == ~w(audio document image text)

    assert contract["events"]["classes"] == ~w(security operational product)
    assert contract["events"]["reject_unknown_payload_keys"]
    assert contract["events"]["max_payload_bytes"] == 4096

    required_catalog_entries =
      contract["events"]["catalog"]
      |> Enum.filter(& &1["required"])

    assert required_catalog_entries != []
    assert Enum.all?(required_catalog_entries, & &1["enabled"])
    assert Enum.all?(contract["events"]["catalog"], &is_list(&1["payload_allowlist"]))

    prohibited = MapSet.new(contract["events"]["prohibited_payload_keys"])

    assert Enum.all?(contract["events"]["catalog"], fn entry ->
             MapSet.disjoint?(MapSet.new(entry["payload_allowlist"]), prohibited)
           end)

    retention_floors = %{"security" => 365, "operational" => 90, "product" => 30}

    assert Enum.all?(contract["events"]["catalog"], fn entry ->
             entry["retention_days"] >= retention_floors[entry["event_class"]]
           end)

    assert schema["$id"] == "https://matome.app/contracts/v1/system-config.schema.json"
    assert schema["required"] == ~w(schema_version revision desired applied)
    assert fixtures["system_config"]["document"]["revision"] == 7
    assert fixtures["system_config"]["device_application"]["desired_revision"] == 7
    assert fixtures["system_config"]["device_application"]["applied_revision"] == 6
  end

  test "records the reset-safe data model decisions" do
    decisions = read_json!(@contract_path)["data_model_decisions"]

    assert decisions["retain"] == ["items", "file_blobs", "text_contents"]

    assert decisions["avoid_domain_tables"] ==
             ["processing_attempts", "derivations", "upload_sessions"]

    assert decisions["migration_policy"] == "clean_schema_reset"
    assert decisions["reason"] == "no_users_and_no_deployment"
  end

  test "the remaining cross-runtime mismatches are executable failing proofs" do
    mismatches = read_json!(@mismatches_path)["mismatches"]

    detected = Map.new(mismatches, &{&1["id"], detect_violation(&1)})
    expected = Map.new(mismatches, &{&1["id"], &1["expected_violation"]})

    assert detected == expected

    assert Map.keys(detected) == ["retry"]
  end

  defp detect_violation(%{"id" => "retry", "current" => current}) do
    if current["jobs_after_second_process"] == 1 and
         current["first_job_identity"] == current["second_job_identity"] and
         "completed" in current["dedupe_states"] do
      "processing.retry_reuses_completed_run"
    end
  end

  defp read_json!(path), do: path |> File.read!() |> Jason.decode!()
end
