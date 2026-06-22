defmodule MatomeApiWeb.RecordingControllerTest do
  use MatomeApiWeb.ConnCase, async: true

  alias MatomeApi.Repo

  @password "correct horse battery staple"

  test "authenticated users CRUD only their own recordings", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    %{conn: other_conn} = register_conn(build_conn())

    create_conn =
      post(owner_conn, ~p"/api/recordings", %{title: "Morning memo", summary: "Owned"})

    recording = json_response(create_conn, 201)["recording"]
    upload = json_response(create_conn, 201)["upload"]

    assert recording["status"] == "pending"

    assert recording["storage_key"] ==
             "owners/#{recording["owner_id"]}/recordings/#{recording["id"]}/media"

    assert upload["method"] == "PUT"
    assert upload["storage_key"] == recording["storage_key"]
    assert upload["expires_in"] == 900
    assert upload["url"] =~ "/media/#{recording["storage_key"]}?"
    assert upload["url"] =~ "X-Amz-Signature="
    assert get(owner_conn, ~p"/api/recordings/#{recording["id"]}") |> json_response(200)
    assert get(other_conn, ~p"/api/recordings/#{recording["id"]}") |> json_response(404)

    list = get(other_conn, ~p"/api/recordings") |> json_response(200)
    assert list["recordings"] == []

    updated =
      put(owner_conn, ~p"/api/recordings/#{recording["id"]}", %{status: "done"})
      |> json_response(200)

    assert updated["recording"]["status"] == "done"

    assert delete(other_conn, ~p"/api/recordings/#{recording["id"]}") |> json_response(404)
    assert delete(owner_conn, ~p"/api/recordings/#{recording["id"]}") |> response(204) == ""
  end

  test "notes and transcript are independent: PATCH one leaves the other untouched", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)

    recording =
      post(owner_conn, ~p"/api/recordings", %{
        title: "Notes vs transcript",
        transcript: "original transcript",
        notes: "original notes"
      })
      |> json_response(201)
      |> get_in(["recording"])

    # GET returns notes
    fetched =
      get(owner_conn, ~p"/api/recordings/#{recording["id"]}")
      |> json_response(200)
      |> get_in(["recording"])

    assert fetched["notes"] == "original notes"
    assert fetched["transcript"] == "original transcript"

    # PATCH notes only -> transcript untouched
    patched_notes =
      put(owner_conn, ~p"/api/recordings/#{recording["id"]}", %{notes: "edited notes"})
      |> json_response(200)
      |> get_in(["recording"])

    assert patched_notes["notes"] == "edited notes"
    assert patched_notes["transcript"] == "original transcript"

    # PATCH transcript only -> notes untouched
    patched_transcript =
      put(owner_conn, ~p"/api/recordings/#{recording["id"]}", %{transcript: "edited transcript"})
      |> json_response(200)
      |> get_in(["recording"])

    assert patched_transcript["transcript"] == "edited transcript"
    assert patched_transcript["notes"] == "edited notes"
  end

  test "presigned download URLs are owner scoped and short lived", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    %{conn: other_conn} = register_conn(build_conn())

    recording =
      post(owner_conn, ~p"/api/recordings", %{title: "Downloadable"})
      |> json_response(201)
      |> get_in(["recording"])

    assert get(other_conn, ~p"/api/recordings/#{recording["id"]}/download-url")
           |> json_response(404)

    download =
      get(owner_conn, ~p"/api/recordings/#{recording["id"]}/download-url")
      |> json_response(200)
      |> get_in(["download"])

    assert download["method"] == "GET"
    assert download["storage_key"] == recording["storage_key"]
    assert download["expires_in"] == 300
    assert download["url"] =~ "/media/#{recording["storage_key"]}?"
    assert download["url"] =~ "X-Amz-Expires=300"
  end

  test "client supplied storage keys are ignored", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)

    response =
      post(owner_conn, ~p"/api/recordings", %{
        title: "Scoped upload",
        storage_key: "owners/elsewhere/recordings/999/media"
      })
      |> json_response(201)

    recording = response["recording"]

    assert recording["storage_key"] ==
             "owners/#{recording["owner_id"]}/recordings/#{recording["id"]}/media"

    assert response["upload"]["storage_key"] == recording["storage_key"]
    refute response["upload"]["url"] =~ "owners/elsewhere"
  end

  test "create rejects a mislabeled media_type", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)

    body =
      post(owner_conn, ~p"/api/recordings", %{title: "Bad type", media_type: "video"})
      |> json_response(422)

    assert %{"media_type" => ["is invalid"]} = body["errors"]
  end

  test "create rejects an oversized declared upload (server-side 25 MB cap)", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    oversized = 25 * 1024 * 1024 + 1

    body =
      post(owner_conn, ~p"/api/recordings", %{title: "Too big", content_length: oversized})
      |> json_response(413)

    assert body["error"] == "upload_too_large"
    assert body["max_bytes"] == 25 * 1024 * 1024
  end

  test "create signs the declared content length into the presigned PUT URL", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)

    response =
      post(owner_conn, ~p"/api/recordings", %{title: "Sized", content_length: 2_048})
      |> json_response(201)

    upload = response["upload"]
    assert upload["max_bytes"] == 25 * 1024 * 1024
    assert upload["content_length"] == 2_048
    assert upload["url"] =~ "X-Amz-SignedHeaders=content-length%3Bhost"
  end

  test "declared content_length is persisted as byte_size and read back", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)

    recording =
      post(owner_conn, ~p"/api/recordings", %{title: "Sized file", content_length: 2_516_582})
      |> json_response(201)
      |> get_in(["recording"])

    assert recording["byte_size"] == 2_516_582

    # Round-trips through a fresh GET (persisted, not just echoed from create).
    fetched =
      get(owner_conn, ~p"/api/recordings/#{recording["id"]}")
      |> json_response(200)
      |> get_in(["recording"])

    assert fetched["byte_size"] == 2_516_582
  end

  test "a recording created without a content_length carries a null byte_size", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)

    recording =
      post(owner_conn, ~p"/api/recordings", %{title: "No size"})
      |> json_response(201)
      |> get_in(["recording"])

    assert recording["byte_size"] == nil

    fetched =
      get(owner_conn, ~p"/api/recordings/#{recording["id"]}")
      |> json_response(200)
      |> get_in(["recording"])

    assert fetched["byte_size"] == nil
  end

  test "upload completion queues AI processing without exposing the AI engine", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)

    recording =
      post(owner_conn, ~p"/api/recordings", %{title: "Needs processing", media_type: "audio"})
      |> json_response(201)
      |> get_in(["recording"])

    response =
      post(owner_conn, ~p"/api/recordings/#{recording["id"]}/process")
      |> json_response(202)

    assert response["processing"] == %{"queued" => true}
    assert response["recording"]["status"] == "pending"

    [job] = Repo.all(Oban.Job)
    assert job.queue == "ai"
    assert job.worker == "MatomeApi.AIEngine.DispatchJob"
    assert job.args == %{"recording_id" => recording["id"]}
  end

  test "recording search and workspace assignment are owner scoped", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    %{conn: other_conn} = register_conn(build_conn())

    other_workspace =
      post(other_conn, ~p"/api/spaces", %{name: "Other"})
      |> json_response(201)
      |> get_in(["workspace"])

    invalid =
      post(owner_conn, ~p"/api/recordings", %{
        title: "Secret",
        workspace_id: other_workspace["id"]
      })

    assert %{"errors" => %{"workspace_id" => ["is invalid"]}} = json_response(invalid, 422)

    post(owner_conn, ~p"/api/recordings", %{title: "Searchable", transcript: "needle"})
    post(other_conn, ~p"/api/recordings", %{title: "Searchable", transcript: "needle"})

    search = get(owner_conn, ~p"/api/recordings/search?q=needle") |> json_response(200)
    assert length(search["recordings"]) == 1
  end

  defp register_conn(conn) do
    email = "user-#{System.unique_integer([:positive])}@example.com"
    register_conn = post(conn, ~p"/api/auth/register", %{email: email, password: @password})
    %{"access_token" => access_token, "user" => user} = json_response(register_conn, 201)

    %{
      conn: build_conn() |> put_req_header("authorization", "Bearer #{access_token}"),
      user: user
    }
  end
end
