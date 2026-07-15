defmodule MatomeApi.AIEngine.DispatchJobTest do
  use MatomeApi.DataCase, async: false

  import Ecto.Query

  alias MatomeApi.Admin
  alias MatomeApi.Auth
  alias MatomeApi.AIEngine.DispatchJob
  alias MatomeApi.Content
  alias MatomeApi.SystemConfig

  @password "correct horse battery staple"

  test "perform dispatches a persisted item file job to the AI engine" do
    parent = self()
    previous = Application.fetch_env!(:matome_api, MatomeApi.AIEngine)

    Application.put_env(
      :matome_api,
      MatomeApi.AIEngine,
      Keyword.merge(previous,
        dispatch_adapter: {__MODULE__.Adapter, parent},
        endpoint: "http://ai.test/jobs",
        dispatch_token: "test-dispatch-token",
        callback_signing_secret: "test-callback-signing-secret",
        callback_base_url: "http://core.test"
      )
    )

    on_exit(fn -> Application.put_env(:matome_api, MatomeApi.AIEngine, previous) end)

    {:ok, %{user: user}} =
      Auth.register_user(%{
        email: "dispatch-#{System.unique_integer([:positive])}@example.com",
        password: @password
      })

    {:ok, matome} = Content.create_matome(user, %{title: "Dispatch"})

    {:ok, item} =
      Content.create_file_item(user, matome.id, %{
        byte_size: 123,
        checksum_sha256: String.duplicate("a", 64),
        content_type: "audio/wav",
        media_type: "audio"
      })

    item.file_blob
    |> Ecto.Changeset.change(
      upload_state: "uploaded",
      uploaded_at: DateTime.utc_now() |> DateTime.truncate(:second)
    )
    |> MatomeApi.Repo.update!()

    revision = SystemConfig.current_revision()
    assert {:ok, queued_item} = Content.enqueue_item_processing(user, item.id)
    assert queued_item.processing_config_revision == revision

    job = Repo.one!(from job in Oban.Job, where: job.worker == "MatomeApi.AIEngine.DispatchJob")
    assert job.args["config_revision"] == revision
    assert job.args["processing_run_id"] == queued_item.processing_run_id
    assert job.args["job_id"] == Content.processing_job_id(queued_item.processing_run_id)

    assert job.args["retry"] == %{
             "max_attempts" => 5,
             "base_delay_seconds" => 2,
             "max_delay_seconds" => 300
           }

    assert job.args["processing"] == %{
             "enabled_input_kinds" => ["audio", "image", "document", "text"],
             "job_timeout_seconds" => 1800
           }

    assert job.args["system_config"]["revision"] == revision
    assert job.args["system_config"]["ai"] == job.args["processing"]
    assert job.args["system_config"]["retry"] == job.args["retry"]
    assert job.args["system_config"]["uploads"]["max_bytes"] == 2_147_483_648

    assert job.max_attempts == 5

    desired = put_in(SystemConfig.desired(), ["retry", "max_attempts"], 6)

    assert {:ok, _config} =
             Admin.update_system_config(desired, revision,
               actor: %{email: "admin@example.com"},
               otp_verified_at: System.os_time(:second),
               remote_ip: "198.51.100.24"
             )

    assert Content.get_item(user, item.id).processing_config_revision == revision
    assert Repo.get!(Oban.Job, job.id).args == job.args

    assert :ok =
             DispatchJob.perform(%Oban.Job{
               args: job.args
             })

    assert_receive {:dispatch, "http://ai.test/jobs", "test-dispatch-token", payload}
    assert payload.contract_version == "1"
    assert payload.job_id == Content.processing_job_id(queued_item.processing_run_id)
    assert payload.run_id == queued_item.processing_run_id
    assert payload.item_id == item.id
    assert payload.input.kind == "audio"
    assert payload.input.media.method == "GET"
    assert payload.callback.url == "http://core.test/internal/v1/jobs/#{payload.job_id}/result"
    assert payload.callback.headers.authorization =~ "Bearer "
    assert Content.get_item(user, item.id).processing_state == :succeeded
  end

  defmodule Adapter do
    alias MatomeApi.Content

    def dispatch(endpoint, token, payload, timeout_seconds, parent) do
      assert timeout_seconds == 1800
      send(parent, {:dispatch, endpoint, token, payload})

      assert {:ok, :applied} =
               Content.apply_processing_callback(payload.job_id, %{
                 "contract_version" => "1",
                 "job_id" => payload.job_id,
                 "run_id" => payload.run_id,
                 "item_id" => payload.item_id,
                 "input_revision" => payload.input_revision,
                 "status" => "done",
                 "outputs" => [
                   %{
                     "type" => "transcript",
                     "text" => "Callback before dispatch acknowledgement."
                   },
                   %{"type" => "summary", "markdown" => "Race-safe."},
                   %{"type" => "title", "text" => "Race-safe callback"}
                 ]
               })

      {:ok,
       %{
         "contract_version" => "1",
         "job_id" => payload.job_id,
         "run_id" => payload.run_id,
         "accepted" => true
       }}
    end
  end
end
