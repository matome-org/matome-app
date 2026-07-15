defmodule MatomeApiWeb.ItemControllerTest do
  use MatomeApiWeb.ConnCase, async: false

  alias MatomeApi.Auth
  alias MatomeApi.Content
  alias MatomeApi.Content.Workspace
  alias MatomeApi.Repo

  @password "correct horse battery staple"
  @token "dev-ai-token"

  test "file create returns the W0 top-level upload envelope", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    response =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        client_id: "rec_local_contract",
        item_type: "file",
        title: "Contract recording",
        notes: "User-authored note",
        workspace_id: nil,
        filename: "contract.wav",
        content_type: "audio/wav",
        checksum_sha256: String.duplicate("a", 64),
        byte_size: 1234,
        media_type: "audio"
      })
      |> json_response(201)

    assert response["contract_version"] == "1"
    assert response["item"]["client_id"] == "rec_local_contract"
    assert response["item"]["title"] == "Contract recording"
    assert response["item"]["notes"] == "User-authored note"
    assert response["item"]["workspace_id"] == nil
    assert response["item"]["processing_state"] == "not_requested"
    assert response["item"]["source_revision"] == 1
    assert response["item"]["metadata"] == %{}

    assert response["item"]["file"]
           |> Map.take(~w(filename content_type checksum_sha256 upload_state upload_generation)) ==
             %{
               "filename" => "contract.wav",
               "content_type" => "audio/wav",
               "checksum_sha256" => String.duplicate("a", 64),
               "upload_state" => "pending",
               "upload_generation" => 1
             }

    refute Map.has_key?(response["item"], "presign")

    assert %{
             "upload_id" => upload_id,
             "upload_generation" => 1,
             "mode" => "single",
             "state" => "pending",
             "expires_at" => expires_at,
             "request" => %{
               "method" => "PUT",
               "url" => url,
               "headers" => %{"content-length" => "1234"}
             }
           } = response["upload"]

    assert is_binary(upload_id)
    assert {:ok, _expires_at, 0} = DateTime.from_iso8601(expires_at)
    assert url =~ "X-Amz-Signature="
  end

  test "replaying owner client_id returns one item, one quota reservation, and a fresh upload",
       %{conn: conn} do
    %{conn: owner_conn, user: owner} = register_conn(conn)
    {:ok, workspace} = Content.create_workspace(owner, %{name: "Replay quota"})

    workspace
    |> Workspace.admin_changeset(%{quota_bytes: 10_000})
    |> Repo.update!()

    matome = create_matome!(owner_conn, %{workspace_id: workspace.id})

    params = %{
      client_id: "rec_local_replay",
      item_type: "file",
      content_length: 1234,
      media_type: "audio",
      title: "Replay",
      metadata: %{display: "compact"}
    }

    first =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", params)
      |> json_response(201)

    Process.sleep(1_100)

    second =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", params)
      |> json_response(201)

    assert second["item"]["id"] == first["item"]["id"]
    assert second["upload"]["upload_id"] == first["upload"]["upload_id"]
    assert second["upload"]["expires_at"] > first["upload"]["expires_at"]
    refute second["upload"]["request"]["url"] == first["upload"]["request"]["url"]
    assert Repo.aggregate(MatomeApi.Content.Item, :count, :id) == 1
    assert Repo.aggregate(MatomeApi.Content.FileBlob, :count, :id) == 1
    assert Repo.get!(Workspace, workspace.id).used_bytes == 1234
  end

  test "conflicting owner client_id reuse returns stable 409", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    assert post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
             client_id: "rec_local_conflict",
             item_type: "file",
             byte_size: 123,
             media_type: "audio"
           })
           |> json_response(201)

    assert post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
             client_id: "rec_local_conflict",
             item_type: "file",
             byte_size: 456,
             media_type: "audio"
           })
           |> json_response(409) == %{"error" => "client_id_conflict"}

    assert Repo.aggregate(MatomeApi.Content.Item, :count, :id) == 1
    assert Repo.aggregate(MatomeApi.Content.FileBlob, :count, :id) == 1
  end

  test "the same client_id is isolated between owners", %{conn: conn} do
    %{conn: first_conn} = register_conn(conn)
    %{conn: second_conn} = register_conn(build_conn())
    first_matome = create_matome!(first_conn)
    second_matome = create_matome!(second_conn)

    create = fn owner_conn, matome ->
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        client_id: "rec_local_shared",
        item_type: "file",
        byte_size: 123,
        media_type: "audio"
      })
      |> json_response(201)
    end

    first = create.(first_conn, first_matome)
    second = create.(second_conn, second_matome)

    refute first["item"]["id"] == second["item"]["id"]
    assert Repo.aggregate(MatomeApi.Content.Item, :count, :id) == 2
  end

  test "creates text items without presign, upload queue, or AI dispatch", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)

    matome = create_matome!(owner_conn)

    item =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        item_type: "text",
        position: 0,
        body: "Plain note"
      })
      |> json_response(201)
      |> Map.fetch!("item")

    assert item["item_type"] == "text"
    assert item["text"]["body"] == "Plain note"
    assert item["file"] == nil
    refute Map.has_key?(item, "presign")

    assert Repo.aggregate(Oban.Job, :count, :id) == 0
  end

  test "item routes reject cross-owner access", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    %{conn: other_conn} = register_conn(build_conn())

    matome = create_matome!(owner_conn)

    item =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        item_type: "text",
        position: 0,
        body: "Private"
      })
      |> json_response(201)
      |> Map.fetch!("item")

    assert get(other_conn, ~p"/api/matomes/#{matome["id"]}/items") |> json_response(404)
    assert get(other_conn, ~p"/api/items/#{item["id"]}") |> json_response(404)
    assert post(other_conn, ~p"/api/items/#{item["id"]}/presign", %{}) |> json_response(404)
    assert delete(other_conn, ~p"/api/items/#{item["id"]}") |> json_response(404)
  end

  test "create returns validation errors for invalid item payloads", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    response =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        item_type: "text",
        position: 0
      })
      |> json_response(422)

    assert %{"errors" => %{"body" => [_ | _]}} = response
  end

  test "presign rejects text items and file item keys are owner namespaced", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    text_item =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        item_type: "text",
        position: 0,
        body: "No file"
      })
      |> json_response(201)
      |> Map.fetch!("item")

    assert post(owner_conn, ~p"/api/items/#{text_item["id"]}/presign", %{"byte_size" => 12})
           |> json_response(422) == %{"error" => "text_item_not_presignable"}

    file_response =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        item_type: "file",
        position: 1,
        byte_size: 1234,
        media_type: "audio",
        duration: 7
      })
      |> json_response(201)

    file_item = Map.fetch!(file_response, "item")

    refute Map.has_key?(file_item["file"], "storage_key")
    refute Map.has_key?(file_response["upload"]["request"], "storage_key")
    assert file_response["upload"]["request"]["method"] == "PUT"

    assert post(owner_conn, ~p"/api/items/#{file_item["id"]}/presign", %{"byte_size" => -1})
           |> json_response(422) == %{"error" => "invalid_content_length"}
  end

  test "deleting a file item reaps its storage object", %{conn: conn} do
    parent = self()
    previous = Application.get_env(:matome_api, MatomeApi.Storage.ObjectStore)

    Application.put_env(:matome_api, MatomeApi.Storage.ObjectStore,
      adapter: {__MODULE__.ObjectStore, parent}
    )

    on_exit(fn ->
      if previous do
        Application.put_env(:matome_api, MatomeApi.Storage.ObjectStore, previous)
      else
        Application.delete_env(:matome_api, MatomeApi.Storage.ObjectStore)
      end
    end)

    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    item =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        item_type: "file",
        position: 0,
        byte_size: 123,
        media_type: "audio"
      })
      |> json_response(201)
      |> Map.fetch!("item")

    storage_key = Repo.get!(MatomeApi.Content.FileBlob, item["file"]["id"]).storage_key

    assert delete(owner_conn, ~p"/api/items/#{item["id"]}") |> response(204) == ""
    assert_receive {:delete_object, ^storage_key}
  end

  test "unsupported file media types do not enqueue AI dispatch", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
      item_type: "file",
      position: 0,
      byte_size: 123,
      media_type: "document"
    })
    |> json_response(201)

    assert Repo.aggregate(Oban.Job, :count, :id) == 0
  end

  test "video file items are accepted without AI dispatch", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    item =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        item_type: "file",
        position: 0,
        byte_size: 123,
        media_type: "video",
        duration: 5,
        metadata: %{"display" => "wide"}
      })
      |> json_response(201)
      |> Map.fetch!("item")

    assert item["item_type"] == "file"
    assert item["file"]["media_type"] == "video"
    assert item["metadata"] == %{"display" => "wide"}
    assert Repo.aggregate(Oban.Job, :count, :id) == 0
  end

  test "item metadata rejects storage/query payload keys", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    response =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        item_type: "file",
        position: 0,
        byte_size: 123,
        media_type: "video",
        metadata: %{"storage_key" => "owners/1/items/evil"}
      })
      |> json_response(422)

    assert %{"errors" => %{"metadata" => [_ | _]}} = response
  end

  test "file processing requires a verified upload and stores callback outputs on the item", %{
    conn: conn
  } do
    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    item =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        item_type: "file",
        position: 0,
        byte_size: 123,
        media_type: "audio"
      })
      |> json_response(201)
      |> Map.fetch!("item")

    # Create must NOT dispatch — the object is not uploaded yet. The client
    # kicks AI off explicitly after upload via POST /items/:id/process.
    assert Repo.aggregate(Oban.Job, :count, :id) == 0

    assert post(owner_conn, ~p"/api/items/#{item["id"]}/process", %{})
           |> json_response(422) == %{"error" => "upload_not_complete"}

    Repo.get!(MatomeApi.Content.FileBlob, item["file"]["id"])
    |> Ecto.Changeset.change(
      upload_state: "uploaded",
      uploaded_at: DateTime.utc_now() |> DateTime.truncate(:second)
    )
    |> Repo.update!()

    queued =
      post(owner_conn, ~p"/api/items/#{item["id"]}/process", %{})
      |> json_response(202)
      |> Map.fetch!("item")

    assert queued["processing_state"] == "queued"
    assert is_binary(queued["processing_run_id"])
    assert queued["file"]["upload_state"] == "uploaded"

    assert Repo.aggregate(Oban.Job, :count, :id) == 1

    blob_id = item["file"]["id"]

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{@token}")
      |> post("/internal/jobs/item:#{item["id"]}:file_blob:#{blob_id}/result", %{
        "job_id" => "item:#{item["id"]}:file_blob:#{blob_id}",
        "item_id" => item["id"],
        "file_blob_id" => blob_id,
        "transcript" => "hello world",
        "summary" => "short summary"
      })

    assert response(conn, 204) == ""

    reloaded =
      get(owner_conn, ~p"/api/items/#{item["id"]}") |> json_response(200) |> Map.fetch!("item")

    assert reloaded["processing_state"] == "succeeded"

    assert reloaded["processing_outputs"] == %{
             "summary" => %{"markdown" => "short summary", "type" => "summary"},
             "transcript" => %{"text" => "hello world", "type" => "transcript"}
           }

    refute Map.has_key?(reloaded["file"], "transcript")
    refute Map.has_key?(reloaded["file"], "summary")
  end

  test "callback route job id must match persisted dispatch args", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    item =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        item_type: "file",
        byte_size: 123,
        media_type: "audio"
      })
      |> json_response(201)
      |> Map.fetch!("item")

    blob_id = item["file"]["id"]

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{@token}")
      |> post("/internal/jobs/item:#{item["id"]}:file_blob:#{blob_id}/result", %{
        "job_id" => "item:#{item["id"]}:file_blob:#{blob_id + 1}",
        "item_id" => item["id"],
        "file_blob_id" => blob_id,
        "transcript" => "forged"
      })

    assert json_response(conn, 404) == %{"error" => "not_found"}

    reloaded =
      get(owner_conn, ~p"/api/items/#{item["id"]}") |> json_response(200) |> Map.fetch!("item")

    assert reloaded["file"]["transcript"] == nil
  end

  test "deleting a matome deletes item payload rows and reaps file storage", %{conn: conn} do
    parent = self()
    previous = Application.get_env(:matome_api, MatomeApi.Storage.ObjectStore)

    Application.put_env(:matome_api, MatomeApi.Storage.ObjectStore,
      adapter: {__MODULE__.ObjectStore, parent}
    )

    on_exit(fn ->
      if previous do
        Application.put_env(:matome_api, MatomeApi.Storage.ObjectStore, previous)
      else
        Application.delete_env(:matome_api, MatomeApi.Storage.ObjectStore)
      end
    end)

    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    text_item =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        item_type: "text",
        body: "Delete me"
      })
      |> json_response(201)
      |> Map.fetch!("item")

    file_item =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        item_type: "file",
        byte_size: 123,
        media_type: "audio"
      })
      |> json_response(201)
      |> Map.fetch!("item")

    storage_key = Repo.get!(MatomeApi.Content.FileBlob, file_item["file"]["id"]).storage_key

    assert delete(owner_conn, ~p"/api/matomes/#{matome["id"]}") |> response(204) == ""
    assert Repo.get(MatomeApi.Content.Item, file_item["id"]) == nil
    assert Repo.get(MatomeApi.Content.FileBlob, file_item["file"]["id"]) == nil
    assert Repo.get(MatomeApi.Content.TextContent, text_item["text"]["id"]) == nil
    assert_receive {:delete_object, ^storage_key}
  end

  test "file item create accepts client content_length and persists it as byte_size", %{
    conn: conn
  } do
    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    item =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        item_type: "file",
        position: 0,
        media_type: "audio",
        content_length: 8192
      })
      |> json_response(201)
      |> Map.fetch!("item")

    assert item["file"]["byte_size"] == 8192
    assert Repo.get!(MatomeApi.Content.FileBlob, item["file"]["id"]).byte_size == 8192
  end

  test "audio create enqueues no dispatch; repeated /process stays idempotent", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    item =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        item_type: "file",
        position: 0,
        byte_size: 123,
        media_type: "audio"
      })
      |> json_response(201)
      |> Map.fetch!("item")

    assert Repo.aggregate(Oban.Job, :count, :id) == 0

    Repo.get!(MatomeApi.Content.FileBlob, item["file"]["id"])
    |> Ecto.Changeset.change(
      upload_state: "uploaded",
      uploaded_at: DateTime.utc_now() |> DateTime.truncate(:second)
    )
    |> Repo.update!()

    assert post(owner_conn, ~p"/api/items/#{item["id"]}/process", %{}) |> json_response(202)
    assert post(owner_conn, ~p"/api/items/#{item["id"]}/process", %{}) |> json_response(202)

    assert Repo.aggregate(Oban.Job, :count, :id) == 1
  end

  test "delete failure returns a generic message and never leaks struct internals", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    item =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        item_type: "file",
        position: 0,
        byte_size: 123,
        media_type: "audio"
      })
      |> json_response(201)
      |> Map.fetch!("item")

    blob_id = item["file"]["id"]

    # Pin the file_blob with a foreign key so deleting it aborts the delete
    # transaction — the branch that previously returned inspect(reason).
    Repo.query!(
      "CREATE TABLE blob_guard (file_blob_id bigint NOT NULL REFERENCES file_blobs(id))"
    )

    Repo.query!("INSERT INTO blob_guard (file_blob_id) VALUES ($1)", [blob_id])

    body = delete(owner_conn, ~p"/api/items/#{item["id"]}") |> json_response(422)

    assert body == %{"error" => "delete_failed"}
    refute body["error"] =~ "Ecto"
    refute body["error"] =~ "ConstraintError"
    # The item survives the rolled-back delete.
    assert Repo.get(MatomeApi.Content.Item, item["id"])
  end

  defmodule ObjectStore do
    def delete_object(storage_key, parent) do
      send(parent, {:delete_object, storage_key})
      :ok
    end
  end

  defp create_matome!(conn, attrs \\ %{}) do
    post(conn, ~p"/api/matomes", Map.put(attrs, :title, "Kickoff"))
    |> json_response(201)
    |> Map.fetch!("matome")
  end

  defp register_conn(conn) do
    email = "user-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, %{user: user, access_token: token}} =
             Auth.register_user(%{email: email, password: @password})

    %{conn: put_req_header(conn, "authorization", "Bearer #{token}"), user: user}
  end
end
