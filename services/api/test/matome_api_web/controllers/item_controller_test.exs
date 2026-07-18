defmodule MatomeApiWeb.ItemControllerTest do
  use MatomeApiWeb.ConnCase, async: false

  import Ecto.Query

  alias MatomeApi.Auth
  alias MatomeApi.AIEngine
  alias MatomeApi.Content
  alias MatomeApi.Content.Workspace
  alias MatomeApi.Events.Event
  alias MatomeApi.Repo

  @password "correct horse battery staple"

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
        client_id: "nested-text-1",
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

    assert post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
             item_type: "text",
             body: "Missing identity"
           })
           |> json_response(422) == %{"errors" => %{"client_id" => ["can't be blank"]}}
  end

  test "standalone text create requires a permanent client id and replays exactly", %{conn: conn} do
    %{conn: owner_conn, user: owner} = register_conn(conn)

    params = %{
      client_id: "text-local-1",
      body: "Standalone body",
      title: "Standalone",
      metadata: %{display: "note-card"}
    }

    first = post(owner_conn, ~p"/api/items/text", params) |> json_response(201)
    replay = post(owner_conn, ~p"/api/items/text", params) |> json_response(201)

    assert first["contract_version"] == "1"
    assert first["item"]["id"] == replay["item"]["id"]
    assert first["item"]["matome_id"] == nil
    assert first["item"]["workspace_id"] == nil
    assert first["item"]["client_id"] == "text-local-1"
    assert first["item"]["text"]["body"] == "Standalone body"
    assert Repo.aggregate(MatomeApi.Content.Item, :count, :id) == 1
    assert Repo.aggregate(MatomeApi.Content.TextContent, :count, :id) == 1

    conflict =
      post(owner_conn, ~p"/api/items/text", Map.put(params, :body, "Conflict"))
      |> json_response(409)

    assert conflict["error"] == "client_id_conflict"
    assert conflict["item"]["id"] == first["item"]["id"]
    assert conflict["item"]["client_id"] == "text-local-1"
    assert conflict["item"]["text"]["body"] == "Standalone body"

    assert post(owner_conn, ~p"/api/items/text", %{body: "No identity"})
           |> json_response(422) == %{"errors" => %{"client_id" => ["can't be blank"]}}

    assert post(owner_conn, ~p"/api/items/text", %{client_id: "no-body"})
           |> json_response(422) == %{"errors" => %{"body" => ["can't be blank"]}}

    {:ok, workspace} = Content.create_workspace(owner, %{name: "Text placement"})
    matome = create_matome!(owner_conn, %{workspace_id: workspace.id})

    placed =
      post(owner_conn, ~p"/api/items/text", %{
        client_id: "text-placed-1",
        body: "Placed body",
        matome_id: matome["id"],
        workspace_id: workspace.id
      })
      |> json_response(201)
      |> Map.fetch!("item")

    assert placed["matome_id"] == matome["id"]
    assert placed["workspace_id"] == workspace.id
  end

  test "nested text conflict returns the existing item snapshot", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    first =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        item_type: "text",
        client_id: "nested-lost-response",
        body: "First local body"
      })
      |> json_response(201)
      |> Map.fetch!("item")

    conflict =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        item_type: "text",
        client_id: "nested-lost-response",
        body: "Changed while response was lost"
      })
      |> json_response(409)

    assert conflict["error"] == "client_id_conflict"
    assert conflict["item"]["id"] == first["id"]
    assert conflict["item"]["source_revision"] == 1
    assert conflict["item"]["text"]["body"] == "First local body"
  end

  test "generic delete rejects text and still deletes files", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    text =
      post(owner_conn, ~p"/api/items/text", %{client_id: "typed-delete", body: "Keep me"})
      |> json_response(201)
      |> Map.fetch!("item")

    file =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        item_type: "file",
        byte_size: 123,
        media_type: "audio"
      })
      |> json_response(201)
      |> Map.fetch!("item")

    assert delete(owner_conn, ~p"/api/items/#{text["id"]}") |> json_response(422) ==
             %{"error" => "text_endpoint_required"}

    assert Repo.get(MatomeApi.Content.Item, text["id"])
    assert delete(owner_conn, ~p"/api/items/#{file["id"]}") |> response(204) == ""
    assert Repo.get(MatomeApi.Content.Item, file["id"]) == nil
  end

  test "text update and delete enforce owner, type, and source revision", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    %{conn: other_conn} = register_conn(build_conn())

    text =
      post(owner_conn, ~p"/api/items/text", %{client_id: "text-guarded", body: "Revision one"})
      |> json_response(201)
      |> Map.fetch!("item")

    matome = create_matome!(owner_conn)

    file =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        item_type: "file",
        byte_size: 123,
        media_type: "audio"
      })
      |> json_response(201)
      |> Map.fetch!("item")

    assert patch(other_conn, ~p"/api/items/#{text["id"]}/text", %{
             body: "Stolen",
             expected_source_revision: 1
           })
           |> json_response(404) == %{"error" => "not_found"}

    assert patch(owner_conn, ~p"/api/items/#{file["id"]}/text", %{
             body: "Wrong type",
             expected_source_revision: 1
           })
           |> json_response(422) == %{"error" => "item_type_mismatch"}

    updated =
      patch(owner_conn, ~p"/api/items/#{text["id"]}/text", %{
        body: "Revision two",
        expected_source_revision: 1
      })
      |> json_response(200)
      |> Map.fetch!("item")

    assert updated["source_revision"] == 2
    assert updated["text"]["body"] == "Revision two"
    assert updated["processing_state"] == "not_requested"
    assert updated["processing_run_id"] == nil
    assert updated["processing_attempt"] == 0
    assert updated["processing_outputs"] == %{}
    assert updated["processing_error"] == nil

    replay =
      patch(owner_conn, ~p"/api/items/#{text["id"]}/text", %{
        body: "Revision two",
        expected_source_revision: 1
      })
      |> json_response(200)

    assert replay["item"]["source_revision"] == 2

    conflict =
      patch(owner_conn, ~p"/api/items/#{text["id"]}/text", %{
        body: "Stale edit",
        expected_source_revision: 1
      })
      |> json_response(409)

    assert conflict["error"] == "version_conflict"
    assert conflict["item"]["source_revision"] == 2
    assert conflict["item"]["text"]["body"] == "Revision two"

    assert delete(owner_conn, ~p"/api/items/#{text["id"]}/text", %{
             expected_source_revision: 1
           })
           |> json_response(409)
           |> Map.take(~w(error)) == %{"error" => "version_conflict"}

    assert delete(other_conn, ~p"/api/items/#{text["id"]}/text", %{
             expected_source_revision: 2
           })
           |> json_response(404) == %{"error" => "not_found"}

    assert delete(owner_conn, ~p"/api/items/#{file["id"]}/text", %{
             expected_source_revision: 1
           })
           |> json_response(422) == %{"error" => "item_type_mismatch"}

    text_content_id = text["text"]["id"]

    assert delete(owner_conn, ~p"/api/items/#{text["id"]}/text", %{
             expected_source_revision: 2
           })
           |> response(204) == ""

    assert Repo.get(MatomeApi.Content.Item, text["id"]) == nil
    assert Repo.get(MatomeApi.Content.TextContent, text_content_id) == nil

    assert delete(owner_conn, ~p"/api/items/#{text["id"]}/text", %{expected_source_revision: 2})
           |> json_response(404) == %{"error" => "not_found"}
  end

  test "item routes reject cross-owner access", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    %{conn: other_conn} = register_conn(build_conn())

    matome = create_matome!(owner_conn)

    item =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        item_type: "file",
        filename: "private.pdf",
        content_type: "application/pdf",
        byte_size: 20,
        media_type: "document"
      })
      |> json_response(201)
      |> Map.fetch!("item")

    mark_file_uploaded!(item)

    assert get(other_conn, ~p"/api/matomes/#{matome["id"]}/items") |> json_response(404)
    assert get(other_conn, ~p"/api/items/#{item["id"]}") |> json_response(404)
    assert post(other_conn, ~p"/api/items/#{item["id"]}/presign", %{}) |> json_response(404)
    assert get(other_conn, ~p"/api/items/#{item["id"]}/download-url") |> json_response(404)
    assert post(other_conn, ~p"/api/items/#{item["id"]}/process", %{}) |> json_response(404)
    assert delete(other_conn, ~p"/api/items/#{item["id"]}") |> json_response(404)
  end

  test "document create persists sanitized safe-open metadata and rejects scripts", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    item =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        item_type: "file",
        filename: "../private/Q3\r\nreport.PDF",
        content_type: "application/pdf",
        byte_size: 1234,
        media_type: "document"
      })
      |> json_response(201)
      |> get_in(["item", "file"])

    assert item["filename"] == "Q3__report.PDF"
    assert item["original_extension"] == "pdf"
    assert item["content_type"] == "application/pdf"
    assert item["byte_size"] == 1234
    assert item["open_policy"] == "external"

    assert post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
             item_type: "file",
             filename: "install.sh",
             content_type: "text/plain",
             byte_size: 42,
             media_type: "document"
           })
           |> json_response(422) == %{"error" => "unsafe_file_type"}

    assert post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
             item_type: "file",
             filename: "install.sh",
             content_type: "audio/wav",
             byte_size: 42,
             media_type: "audio"
           })
           |> json_response(422) == %{"error" => "unsafe_file_type"}
  end

  test "document download descriptor is short lived and signs safe response overrides", %{
    conn: conn
  } do
    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    item =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        item_type: "file",
        filename: "report.pdf",
        content_type: "application/pdf",
        byte_size: 1234,
        media_type: "document"
      })
      |> json_response(201)
      |> Map.fetch!("item")

    assert get(owner_conn, ~p"/api/items/#{item["id"]}/download-url")
           |> json_response(422) == %{"error" => "file_not_uploaded"}

    mark_file_uploaded!(item)

    response = get(owner_conn, ~p"/api/items/#{item["id"]}/download-url")
    assert get_resp_header(response, "cache-control") == ["private, no-store"]
    descriptor = response |> json_response(200) |> Map.fetch!("download")

    assert descriptor["method"] == "GET"
    assert descriptor["filename"] == "report.pdf"
    assert descriptor["content_type"] == "application/pdf"
    assert descriptor["byte_size"] == 1234
    assert descriptor["open_policy"] == "external"
    assert descriptor["action"] == "open"
    assert descriptor["expires_in"] in 1..300
    assert {:ok, _expires_at, 0} = DateTime.from_iso8601(descriptor["expires_at"])

    query = descriptor["url"] |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
    assert query["response-content-type"] == "application/pdf"
    assert query["response-content-disposition"] =~ ~s(inline; filename="report.pdf")
    assert query["response-cache-control"] == "private, no-store, max-age=0"
    assert query["X-Amz-Expires"] == Integer.to_string(descriptor["expires_in"])
    assert query["X-Amz-Signature"]
  end

  test "active and MIME-mismatched documents are forced to attachment or download", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    create = fn filename, content_type ->
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        item_type: "file",
        filename: filename,
        content_type: content_type,
        byte_size: System.unique_integer([:positive]),
        media_type: "document"
      })
      |> json_response(201)
      |> Map.fetch!("item")
    end

    active = create.("page.html", "text/html")
    mismatch = create.("report.pdf", "text/plain")
    mark_file_uploaded!(active)
    mark_file_uploaded!(mismatch)

    active_download =
      get(owner_conn, ~p"/api/items/#{active["id"]}/download-url")
      |> json_response(200)
      |> Map.fetch!("download")

    mismatch_download =
      get(owner_conn, ~p"/api/items/#{mismatch["id"]}/download-url")
      |> json_response(200)
      |> Map.fetch!("download")

    assert active_download["open_policy"] == "attachment_only"
    assert active_download["action"] == "download"
    assert active_download["warning"] == "active_content"
    assert mismatch_download["open_policy"] == "download_only"
    assert mismatch_download["content_type"] == "application/octet-stream"

    for descriptor <- [active_download, mismatch_download] do
      query = descriptor["url"] |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
      assert query["response-content-disposition"] =~ "attachment;"
    end
  end

  test "descriptor issuance downgrades stale permissive policy and blocks newly unsafe metadata",
       %{
         conn: conn
       } do
    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    item =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        item_type: "file",
        filename: "report.pdf",
        content_type: "application/pdf",
        byte_size: 1234,
        media_type: "document"
      })
      |> json_response(201)
      |> Map.fetch!("item")

    mark_file_uploaded!(item)
    blob_id = item["file"]["id"]

    Repo.update_all(from(blob in MatomeApi.Content.FileBlob, where: blob.id == ^blob_id),
      set: [content_type: "text/plain", open_policy: "external"]
    )

    descriptor =
      get(owner_conn, ~p"/api/items/#{item["id"]}/download-url")
      |> json_response(200)
      |> Map.fetch!("download")

    assert descriptor["open_policy"] == "download_only"
    assert Repo.get!(MatomeApi.Content.FileBlob, blob_id).open_policy == "download_only"

    Repo.update_all(from(blob in MatomeApi.Content.FileBlob, where: blob.id == ^blob_id),
      set: [filename: "payload.command", original_extension: "command", open_policy: "external"]
    )

    assert get(owner_conn, ~p"/api/items/#{item["id"]}/download-url")
           |> json_response(422) == %{"error" => "unsafe_file_type"}

    assert Repo.get!(MatomeApi.Content.FileBlob, blob_id).open_policy == "blocked"
  end

  defp mark_file_uploaded!(item) do
    MatomeApi.Content.FileBlob
    |> Repo.get!(item["file"]["id"])
    |> Ecto.Changeset.change(%{
      checksum_sha256: String.duplicate("a", 64),
      upload_state: "uploaded",
      uploaded_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.update!()
  end

  test "create returns validation errors for invalid item payloads", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    response =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/items", %{
        item_type: "text",
        client_id: "invalid-text-payload",
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
        client_id: "presign-text",
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
        checksum_sha256: String.duplicate("a", 64),
        content_type: "audio/wav",
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
        checksum_sha256: String.duplicate("a", 64),
        content_type: "audio/wav",
        filename: "processing-source.wav",
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
    assert queued["processing_attempt"] == 1
    assert queued["processing_requested_outputs"] == ~w(transcript summary title)
    assert queued["processing_deadline_at"]
    assert queued["file"]["upload_state"] == "uploaded"

    assert Repo.aggregate(Oban.Job, :count, :id) == 2

    assert %Event{owner_id: owner_id, subject_type: "item", subject_id: subject_id} =
             Repo.one!(
               from e in Event,
                 where: e.event_key == "operational.upload_completed.v1",
                 order_by: [desc: e.id],
                 limit: 1
             )

    assert owner_id == queued["owner_id"]
    assert subject_id == to_string(item["id"])

    job_id = Content.processing_job_id(queued["processing_run_id"])

    assert {:ok, _payload} =
             Content.ai_dispatch_payload(
               item["id"],
               queued["processing_run_id"],
               queued["source_revision"]
             )

    callback = %{
      "contract_version" => "1",
      "job_id" => job_id,
      "run_id" => queued["processing_run_id"],
      "item_id" => item["id"],
      "input_revision" => queued["source_revision"],
      "status" => "done",
      "outputs" => [
        %{"type" => "transcript", "text" => "hello world"},
        %{"type" => "summary", "markdown" => "short summary"},
        %{"type" => "title", "text" => "Processed title"}
      ]
    }

    conn =
      build_conn()
      |> put_req_header(
        "authorization",
        "Bearer #{AIEngine.callback_identity(job_id, queued["processing_run_id"], queued["source_revision"])}"
      )
      |> post("/internal/v1/jobs/#{job_id}/result", callback)

    assert response(conn, 204) == ""

    assert %Event{owner_id: owner_id, run_id: run_id, subject_id: subject_id} =
             Repo.one!(
               from e in Event,
                 where: e.event_key == "operational.processing_completed.v1",
                 order_by: [desc: e.id],
                 limit: 1
             )

    assert owner_id == queued["owner_id"]
    assert run_id == queued["processing_run_id"]
    assert subject_id == to_string(item["id"])

    reloaded =
      get(owner_conn, ~p"/api/items/#{item["id"]}") |> json_response(200) |> Map.fetch!("item")

    assert reloaded["processing_state"] == "succeeded"

    assert reloaded["processing_outputs"] == %{
             "summary" => %{"markdown" => "short summary", "type" => "summary"},
             "title" => %{"text" => "Processed title", "type" => "title"},
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

    run_id = Ecto.UUID.generate()
    route_job_id = Content.processing_job_id(run_id)

    conn =
      build_conn()
      |> put_req_header(
        "authorization",
        "Bearer #{AIEngine.callback_identity(route_job_id, run_id, 1)}"
      )
      |> post("/internal/v1/jobs/#{route_job_id}/result", %{
        "contract_version" => "1",
        "job_id" => Content.processing_job_id(Ecto.UUID.generate()),
        "run_id" => run_id,
        "item_id" => item["id"],
        "input_revision" => 1,
        "status" => "done",
        "outputs" => [%{"type" => "transcript", "text" => "forged"}]
      })

    assert json_response(conn, 404) == %{"error" => "not_found"}

    reloaded =
      get(owner_conn, ~p"/api/items/#{item["id"]}") |> json_response(200) |> Map.fetch!("item")

    assert reloaded["processing_outputs"] == %{}
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
        client_id: "delete-matome-text",
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
        checksum_sha256: String.duplicate("a", 64),
        content_type: "audio/wav",
        filename: "idempotent-source.wav",
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

    assert Repo.aggregate(Oban.Job, :count, :id) == 2
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
