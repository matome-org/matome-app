defmodule MatomeApiWeb.InternalJobControllerTest do
  use MatomeApiWeb.ConnCase, async: true

  alias MatomeApi.{Auth, Content, Repo}
  alias MatomeApi.Content.Recording

  @password "correct horse battery staple"
  @token "dev-ai-token"

  test "rejects callbacks without the internal service token", %{conn: conn} do
    conn = post(conn, "/internal/jobs/recording:1:attempt:1/result", %{})
    assert json_response(conn, 401) == %{"error" => "unauthorized"}
  end

  test "successful AI callback persists results and fans out status", %{conn: conn} do
    %{user: user} = register_user()

    {:ok, recording} =
      Content.create_recording(user, %{title: "Pending memo", media_type: "audio"})

    {:ok, processing} = Content.mark_recording_processing(recording)
    Phoenix.PubSub.subscribe(MatomeApi.PubSub, "user:#{user.id}")

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{@token}")
      |> post("/internal/jobs/recording:#{recording.id}:attempt:1/result", %{
        job_id: "recording:#{recording.id}:attempt:1",
        recording_id: recording.id,
        status: "done",
        title: "AI title",
        transcript: "AI transcript",
        summary: "AI summary",
        duration: 42,
        badge: "Inbox"
      })

    assert response(conn, 204) == ""

    updated = Repo.get!(Recording, processing.id)
    assert updated.status == :done
    assert updated.title == "AI title"
    assert updated.transcript == "AI transcript"
    assert updated.summary == "AI summary"
    assert updated.duration == 42
    assert updated.badge == "Inbox"

    assert_receive %Phoenix.Socket.Broadcast{
      event: "recording:status",
      payload: %{recording_id: recording_id, status: "done", transcript: "AI transcript"}
    }

    assert recording_id == recording.id
  end

  test "failed AI callback persists failure reason", %{conn: conn} do
    %{user: user} = register_user()

    {:ok, recording} =
      Content.create_recording(user, %{title: "Pending memo", media_type: "video"})

    {:ok, _processing} = Content.mark_recording_processing(recording)

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{@token}")
      |> post("/internal/jobs/recording:#{recording.id}:attempt:1/result", %{
        job_id: "recording:#{recording.id}:attempt:1",
        recording_id: recording.id,
        status: "failed",
        error: %{message: "Unsupported media_type: video"}
      })

    assert response(conn, 204) == ""
    updated = Repo.get!(Recording, recording.id)
    assert updated.status == :failed
    assert updated.error_reason == "Unsupported media_type: video"
  end

  test "callback job id and body job id must match", %{conn: conn} do
    %{user: user} = register_user()
    {:ok, recording} = Content.create_recording(user, %{title: "Pending memo"})

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{@token}")
      |> post("/internal/jobs/recording:#{recording.id}:attempt:1/result", %{
        job_id: "recording:#{recording.id}:attempt:2",
        recording_id: recording.id,
        status: "done"
      })

    assert json_response(conn, 422) == %{"error" => "recording_mismatch"}
  end

  defp register_user do
    email = "user-#{System.unique_integer([:positive])}@example.com"
    {:ok, result} = Auth.register_user(%{email: email, password: @password})
    %{access_token: result.access_token, user: result.user}
  end
end
