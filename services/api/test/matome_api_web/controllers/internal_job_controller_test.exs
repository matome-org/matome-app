defmodule MatomeApiWeb.InternalJobControllerTest do
  use MatomeApiWeb.ConnCase, async: true

  alias MatomeApi.AIEngine
  alias MatomeApi.Auth
  alias MatomeApi.Content
  alias MatomeApi.Repo

  @password "correct horse battery staple"

  test "rejects unsigned callbacks and the separate dispatch credential", %{conn: conn} do
    {_user, item, params} = queued_callback_fixture()

    assert conn
           |> post(callback_path(params), params)
           |> json_response(401) == %{"error" => "unauthorized"}

    assert build_conn()
           |> put_req_header("authorization", "Bearer #{AIEngine.dispatch_token()}")
           |> post(callback_path(params), params)
           |> json_response(401) == %{"error" => "unauthorized"}

    assert Content.processing_job_id(item.processing_run_id) == params["job_id"]
  end

  test "accepts a signed v1 callback and rejects malformed signed payloads", %{conn: conn} do
    {user, item, params} = queued_callback_fixture()
    identity = callback_identity(params)

    assert conn
           |> put_req_header("authorization", "Bearer #{identity}")
           |> post(callback_path(params), params)
           |> response(204) == ""

    assert Content.get_item(user, item.id).processing_state == :partial

    malformed = Map.put(params, "contract_version", "2")

    assert build_conn()
           |> put_req_header("authorization", "Bearer #{identity}")
           |> post(callback_path(malformed), malformed)
           |> json_response(422) == %{"error" => "invalid_callback"}
  end

  test "a valid identity for an unknown persisted job does not disclose item state", %{conn: conn} do
    run_id = Ecto.UUID.generate()

    params = %{
      "contract_version" => "1",
      "job_id" => Content.processing_job_id(run_id),
      "run_id" => run_id,
      "item_id" => 999_999,
      "input_revision" => 1,
      "status" => "failed",
      "error" => %{
        "code" => "processor_unavailable",
        "message" => "Processor unavailable.",
        "retryable" => true
      }
    }

    assert conn
           |> put_req_header("authorization", "Bearer #{callback_identity(params)}")
           |> post(callback_path(params), params)
           |> json_response(404) == %{"error" => "not_found"}
  end

  defp queued_callback_fixture do
    {:ok, %{user: user}} =
      Auth.register_user(%{
        email: "callback-#{System.unique_integer([:positive])}@example.com",
        password: @password
      })

    {:ok, matome} = Content.create_matome(user, %{title: "Callback"})

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
    |> Repo.update!()

    {:ok, queued} = Content.enqueue_item_processing(user, item.id)

    {:ok, _payload} =
      Content.ai_dispatch_payload(
        queued.id,
        queued.processing_run_id,
        queued.source_revision
      )

    params = %{
      "contract_version" => "1",
      "job_id" => Content.processing_job_id(queued.processing_run_id),
      "run_id" => queued.processing_run_id,
      "item_id" => queued.id,
      "input_revision" => queued.source_revision,
      "status" => "done",
      "outputs" => [%{"type" => "summary", "markdown" => "Signed summary."}]
    }

    {user, queued, params}
  end

  defp callback_identity(params) do
    AIEngine.callback_identity(
      params["job_id"],
      params["run_id"],
      params["input_revision"]
    )
  end

  defp callback_path(params), do: "/internal/v1/jobs/#{params["job_id"]}/result"
end
