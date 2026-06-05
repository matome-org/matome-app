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
