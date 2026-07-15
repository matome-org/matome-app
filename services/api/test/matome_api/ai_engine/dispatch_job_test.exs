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
        token: "test-token",
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

    assert job.args["retry"] == %{
             "max_attempts" => 5,
             "base_delay_seconds" => 2,
             "max_delay_seconds" => 300
           }

    assert job.args["processing"] == %{
             "enabled_input_kinds" => ["audio", "image", "document", "text"],
             "job_timeout_seconds" => 1800
           }

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

    assert_receive {:dispatch, "http://ai.test/jobs", "test-token", payload}
    assert payload.job_id == "item:#{item.id}:file_blob:#{item.file_blob_id}"
    assert payload.item_id == item.id
    assert payload.file_blob_id == item.file_blob_id
    assert payload.media.method == "GET"
    assert payload.callback.url == "http://core.test/internal/jobs/#{payload.job_id}/result"
  end

  defmodule Adapter do
    def dispatch(endpoint, token, payload, timeout_seconds, parent) do
      assert timeout_seconds == 1800
      send(parent, {:dispatch, endpoint, token, payload})
      {:ok, "accepted"}
    end
  end
end
