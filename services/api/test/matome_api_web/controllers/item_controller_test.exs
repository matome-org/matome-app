defmodule MatomeApiWeb.ItemControllerTest do
  use MatomeApiWeb.ConnCase, async: false

  alias MatomeApi.Auth
  alias MatomeApi.Repo

  @password "correct horse battery staple"
  @token "dev-ai-token"

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

    file_item =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        item_type: "file",
        position: 1,
        byte_size: 1234,
        media_type: "audio",
        duration: 7
      })
      |> json_response(201)
      |> Map.fetch!("item")

    refute Map.has_key?(file_item["file"], "storage_key")
    refute Map.has_key?(file_item["presign"], "storage_key")
    assert file_item["presign"]["method"] == "PUT"

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

  test "file item preserves upload callback transcript and summary round-trip", %{conn: conn} do
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
           |> json_response(202)

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

    assert reloaded["file"]["transcript"] == "hello world"
    assert reloaded["file"]["summary"] == "short summary"
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

  defp create_matome!(conn) do
    post(conn, ~p"/api/matomes", %{title: "Kickoff"})
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
