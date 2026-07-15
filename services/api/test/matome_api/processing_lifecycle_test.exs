defmodule MatomeApi.ProcessingLifecycleTest do
  use MatomeApi.DataCase, async: false

  alias MatomeApi.Auth
  alias MatomeApi.Content
  alias MatomeApi.Events.Event
  alias MatomeApi.SystemConfig

  @password "correct horse battery staple"

  setup do
    previous = Application.fetch_env!(:matome_api, MatomeApi.AIEngine)

    Application.put_env(
      :matome_api,
      MatomeApi.AIEngine,
      Keyword.put(previous, :capabilities, capabilities())
    )

    on_exit(fn -> Application.put_env(:matome_api, MatomeApi.AIEngine, previous) end)
  end

  test "a terminal user retry creates a new logical run and Oban dispatch" do
    {user, item} = uploaded_file_fixture("audio", "audio/wav")

    assert {:ok, first} = Content.enqueue_item_processing(user, item.id)
    first_run_id = first.processing_run_id
    assert Map.fetch!(first, :processing_attempt) == 1

    first
    |> Ecto.Changeset.change(
      processing_state: :failed,
      processing_error: %{
        "code" => "processor_unavailable",
        "message" => "Processor unavailable.",
        "retryable" => true
      }
    )
    |> Repo.update!()

    assert {:ok, second} = Content.enqueue_item_processing(user, item.id)
    assert second.processing_run_id != first_run_id
    assert Map.fetch!(second, :processing_attempt) == 2

    jobs =
      Oban.Job
      |> where([job], job.worker == "MatomeApi.AIEngine.DispatchJob")
      |> order_by([job], asc: job.id)
      |> Repo.all()

    assert Enum.map(jobs, & &1.args["processing_run_id"]) == [
             first_run_id,
             second.processing_run_id
           ]

    watchdog_runs =
      Oban.Job
      |> where([job], job.worker == "MatomeApi.AIEngine.WatchdogJob")
      |> order_by([job], asc: job.id)
      |> Repo.all()
      |> Enum.map(& &1.args["processing_run_id"])

    assert watchdog_runs == [first_run_id, second.processing_run_id]

    assert Repo.aggregate(
             from(event in Event,
               where:
                 event.event_key == "operational.work_transition.v1" and
                   event.subject_id == ^to_string(item.id)
             ),
             :count
           ) == 2
  end

  test "concurrent transport replays converge on one run under the item lock" do
    {user, item} = uploaded_file_fixture("audio", "audio/wav")

    runs =
      1..2
      |> Enum.map(fn _index ->
        Task.async(fn ->
          {:ok, queued} = Content.enqueue_item_processing(user, item.id)
          queued.processing_run_id
        end)
      end)
      |> Task.await_many()

    assert runs |> Enum.uniq() |> length() == 1
    assert Repo.aggregate(Oban.Job, :count, :id) == 2
  end

  test "audio image document and bounded text runs snapshot tagged v1 inputs" do
    fixtures = [
      {"audio", "audio/wav", ~w(transcript summary title)},
      {"image", "image/jpeg", ~w(ocr_text description summary title)},
      {"document", "application/pdf", ~w(extracted_text summary title)}
    ]

    for {kind, content_type, outputs} <- fixtures do
      {user, item} = uploaded_file_fixture(kind, content_type)

      assert {:ok, queued} = Content.enqueue_item_processing(user, item.id)
      assert queued.processing_state == :queued
      assert queued.processing_attempt == 1
      assert queued.processing_config_revision == SystemConfig.current_revision()
      assert queued.processing_requested_outputs == outputs
      assert content_type in queued.processing_capabilities["input"]["content_types"]

      assert {:ok, payload} =
               Content.ai_dispatch_payload(
                 item.id,
                 queued.processing_run_id,
                 queued.source_revision
               )

      assert payload.contract_version == "1"
      assert payload.run_id == queued.processing_run_id
      assert payload.input_revision == queued.source_revision
      assert payload.input.kind == kind
      assert payload.input.media.content_type == content_type
      assert payload.requested_outputs == outputs
      refute Map.has_key?(payload.input.media, :storage_key)
    end

    {user, item} = text_fixture(String.duplicate("bounded text ", 100))
    assert {:ok, queued} = Content.enqueue_item_processing(user, item.id)

    assert {:ok, payload} =
             Content.ai_dispatch_payload(
               item.id,
               queued.processing_run_id,
               queued.source_revision
             )

    assert payload.input == %{kind: "text", body: item.text_content.body}
    assert payload.requested_outputs == ~w(summary title)
  end

  test "an advertised unavailable input records a terminal run without Oban work" do
    config = Application.fetch_env!(:matome_api, MatomeApi.AIEngine)
    capabilities = put_in(capabilities(), ["inputs", "image", "enabled"], false)

    Application.put_env(
      :matome_api,
      MatomeApi.AIEngine,
      Keyword.put(config, :capabilities, capabilities)
    )

    {user, item} = uploaded_file_fixture("image", "image/jpeg")

    assert {:ok, unavailable} = Content.enqueue_item_processing(user, item.id)
    assert unavailable.processing_state == :not_available
    assert unavailable.processing_attempt == 1
    assert unavailable.processing_run_id
    assert unavailable.processing_requested_outputs == []
    assert Repo.aggregate(Oban.Job, :count, :id) == 0
  end

  test "typed callbacks are conditional, duplicate-safe, partial-aware, and stale-safe" do
    {user, item} = uploaded_file_fixture("audio", "audio/wav")
    assert {:ok, first} = Content.enqueue_item_processing(user, item.id)

    assert {:ok, _payload} =
             Content.ai_dispatch_payload(item.id, first.processing_run_id, first.source_revision)

    done =
      callback(first, "done", %{
        "outputs" => [
          %{
            "type" => "transcript",
            "text" => "Fixture transcript.",
            "language" => "en",
            "duration_ms" => 42_000
          },
          %{"type" => "summary", "markdown" => "Fixture summary."},
          %{"type" => "title", "text" => "Fixture title"}
        ]
      })

    assert {:ok, :applied} = Content.apply_processing_callback(done["job_id"], done)
    assert {:ok, :duplicate} = Content.apply_processing_callback(done["job_id"], done)

    succeeded = Content.get_item(user, item.id)
    assert succeeded.processing_state == :succeeded
    assert succeeded.processing_outputs["transcript"]["text"] == "Fixture transcript."

    assert {:ok, second} = Content.enqueue_item_processing(user, item.id)
    assert second.processing_run_id != first.processing_run_id

    stale = put_in(done, ["outputs", Access.at(0), "text"], "conflicting stale output")
    assert {:ok, :stale} = Content.apply_processing_callback(stale["job_id"], stale)
    assert Content.get_item(user, item.id).processing_state == :queued

    assert {:ok, _payload} =
             Content.ai_dispatch_payload(
               item.id,
               second.processing_run_id,
               second.source_revision
             )

    partial =
      callback(second, "done", %{
        "outputs" => [%{"type" => "summary", "markdown" => "Only summary."}]
      })

    assert {:ok, :applied} = Content.apply_processing_callback(partial["job_id"], partial)
    assert Content.get_item(user, item.id).processing_state == :partial

    completion_events =
      from(event in Event,
        where:
          event.event_key == "operational.processing_completed.v1" and
            event.subject_id == ^to_string(item.id)
      )
      |> Repo.all()

    assert Enum.map(completion_events, & &1.run_id) == [
             first.processing_run_id,
             second.processing_run_id
           ]
  end

  test "failed callbacks and watchdog timeouts preserve stable current-run errors" do
    {user, item} = uploaded_file_fixture("document", "application/pdf")
    assert {:ok, failed_run} = Content.enqueue_item_processing(user, item.id)

    assert {:ok, _payload} =
             Content.ai_dispatch_payload(
               item.id,
               failed_run.processing_run_id,
               failed_run.source_revision
             )

    failed =
      callback(failed_run, "failed", %{
        "error" => %{
          "code" => "processor_unavailable",
          "message" => "Processor unavailable: Bearer leaked-token",
          "retryable" => true
        }
      })

    assert {:ok, :applied} = Content.apply_processing_callback(failed["job_id"], failed)
    failed_item = Content.get_item(user, item.id)
    assert failed_item.processing_state == :failed
    assert failed_item.processing_error["message"] == "Processor unavailable: Bearer [REDACTED]"

    assert {:ok, timeout_run} = Content.enqueue_item_processing(user, item.id)
    assert timeout_run.processing_run_id != failed_run.processing_run_id
    assert timeout_run.processing_attempt == failed_run.processing_attempt + 1

    assert {:ok, {:not_due, seconds}} =
             Content.timeout_item_processing(
               item.id,
               timeout_run.processing_run_id,
               timeout_run.source_revision
             )

    assert seconds > 0

    assert {:ok, :timed_out} =
             Content.timeout_item_processing(
               item.id,
               timeout_run.processing_run_id,
               timeout_run.source_revision,
               DateTime.add(timeout_run.processing_deadline_at, 1, :second)
             )

    timed_out = Content.get_item(user, item.id)
    assert timed_out.processing_state == :failed

    assert timed_out.processing_error == %{
             "code" => "timeout",
             "message" => "Processing deadline exceeded.",
             "retryable" => true
           }

    assert {:ok, :stale} =
             Content.timeout_item_processing(
               item.id,
               failed_run.processing_run_id,
               failed_run.source_revision
             )
  end

  test "callbacks reject unrequested, duplicate, oversized, or wrong-revision output" do
    {user, item} = uploaded_file_fixture("audio", "audio/wav")
    assert {:ok, queued} = Content.enqueue_item_processing(user, item.id)

    valid_but_early =
      callback(queued, "done", %{
        "outputs" => [%{"type" => "summary", "markdown" => "too early"}]
      })

    assert {:error, :not_processing} =
             Content.apply_processing_callback(valid_but_early["job_id"], valid_but_early)

    assert {:discard, :missing_item} =
             Content.ai_dispatch_payload(
               item.id,
               queued.processing_run_id,
               queued.source_revision + 1
             )

    unrequested =
      callback(queued, "done", %{
        "outputs" => [%{"type" => "description", "text" => "not requested"}]
      })

    assert {:error, :invalid_callback} =
             Content.apply_processing_callback(unrequested["job_id"], unrequested)

    duplicate =
      callback(queued, "done", %{
        "outputs" => [
          %{"type" => "summary", "markdown" => "one"},
          %{"type" => "summary", "markdown" => "two"}
        ]
      })

    assert {:error, :invalid_callback} =
             Content.apply_processing_callback(duplicate["job_id"], duplicate)

    oversized =
      callback(queued, "done", %{
        "outputs" => [
          %{"type" => "summary", "markdown" => String.duplicate("x", 4_000_001)}
        ]
      })

    assert {:error, :invalid_callback} =
             Content.apply_processing_callback(oversized["job_id"], oversized)

    wrong_revision = Map.put(unrequested, "input_revision", queued.source_revision + 1)

    assert {:error, :not_found} =
             Content.apply_processing_callback(wrong_revision["job_id"], wrong_revision)

    unchanged = Content.get_item(user, item.id)
    assert unchanged.processing_state == :queued
    assert unchanged.processing_outputs == %{}
  end

  defp uploaded_file_fixture(media_type, content_type) do
    {:ok, %{user: user}} =
      Auth.register_user(%{
        email: "processing-#{System.unique_integer([:positive])}@example.com",
        password: @password
      })

    {:ok, matome} = Content.create_matome(user, %{title: "Processing"})

    {:ok, item} =
      Content.create_file_item(user, matome.id, %{
        byte_size: 123,
        checksum_sha256: String.duplicate("a", 64),
        content_type: content_type,
        media_type: media_type
      })

    item.file_blob
    |> Ecto.Changeset.change(
      upload_state: "uploaded",
      uploaded_at: DateTime.utc_now() |> DateTime.truncate(:second)
    )
    |> Repo.update!()

    {user, Content.get_item(user, item.id)}
  end

  defp text_fixture(body) do
    {:ok, %{user: user}} =
      Auth.register_user(%{
        email: "processing-text-#{System.unique_integer([:positive])}@example.com",
        password: @password
      })

    {:ok, matome} = Content.create_matome(user, %{title: "Processing text"})
    {:ok, item} = Content.create_text_item(user, matome.id, %{body: body})
    {user, item}
  end

  defp callback(item, status, terminal) do
    Map.merge(
      %{
        "contract_version" => "1",
        "job_id" => processing_job_id(item.processing_run_id),
        "run_id" => item.processing_run_id,
        "item_id" => item.id,
        "input_revision" => item.source_revision,
        "status" => status
      },
      terminal
    )
  end

  defp processing_job_id(run_id), do: "job_#{String.replace(run_id, "-", "")}"

  defp capabilities do
    %{
      "contract_version" => "1",
      "service" => "matome-ai-test",
      "inputs" => %{
        "audio" => %{
          "enabled" => true,
          "max_bytes" => 2_147_483_648,
          "content_types" => ["audio/wav", "application/octet-stream"],
          "outputs" => ~w(transcript summary title)
        },
        "image" => %{
          "enabled" => true,
          "max_bytes" => 52_428_800,
          "content_types" => ["image/jpeg", "image/png", "application/octet-stream"],
          "outputs" => ~w(ocr_text description summary title)
        },
        "document" => %{
          "enabled" => true,
          "max_bytes" => 524_288_000,
          "content_types" => ["application/pdf", "text/plain", "application/octet-stream"],
          "outputs" => ~w(extracted_text summary title)
        },
        "text" => %{
          "enabled" => true,
          "max_characters" => 200_000,
          "outputs" => ~w(summary title)
        }
      }
    }
  end
end
