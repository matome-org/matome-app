defmodule MatomeApi.AIEngine.DispatchJobTest do
  use MatomeApi.DataCase, async: false

  alias MatomeApi.Auth
  alias MatomeApi.AIEngine.DispatchJob
  alias MatomeApi.Content

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
      Content.create_file_item(user, matome.id, %{byte_size: 123, media_type: "audio"})

    assert :ok =
             DispatchJob.perform(%Oban.Job{
               args: %{"item_id" => item.id, "file_blob_id" => item.file_blob_id}
             })

    assert_receive {:dispatch, "http://ai.test/jobs", "test-token", payload}
    assert payload.job_id == "item:#{item.id}:file_blob:#{item.file_blob_id}"
    assert payload.item_id == item.id
    assert payload.file_blob_id == item.file_blob_id
    assert payload.media.method == "GET"
    assert payload.callback.url == "http://core.test/internal/jobs/#{payload.job_id}/result"
  end

  defmodule Adapter do
    def dispatch(endpoint, token, payload, parent) do
      send(parent, {:dispatch, endpoint, token, payload})
      {:ok, "accepted"}
    end
  end
end
