defmodule MatomeApiWeb.UploadControllerTest do
  use MatomeApiWeb.ConnCase, async: false

  alias MatomeApi.Auth
  alias __MODULE__.Store
  alias MatomeApi.Content
  alias MatomeApi.Content.{FileBlob, UploadCleanupJob, Workspace}
  alias MatomeApi.Repo

  @password "correct horse battery staple"
  @large_bytes 30 * 1024 * 1024
  @whole_checksum String.duplicate("a", 64)
  @part_one_checksum String.duplicate("b", 64)
  @part_two_checksum String.duplicate("c", 64)

  setup do
    {:ok, store} = Agent.start_link(fn -> Store.initial_state() end)
    previous = Application.get_env(:matome_api, MatomeApi.Storage.ObjectStore)

    Application.put_env(:matome_api, MatomeApi.Storage.ObjectStore, adapter: {Store, store})

    on_exit(fn ->
      if Process.alive?(store), do: Agent.stop(store)

      if previous do
        Application.put_env(:matome_api, MatomeApi.Storage.ObjectStore, previous)
      else
        Application.delete_env(:matome_api, MatomeApi.Storage.ObjectStore)
      end
    end)

    {:ok, store: store}
  end

  test "multipart upload resumes missing parts and completes exactly once", %{
    conn: conn,
    store: store
  } do
    %{conn: owner_conn, user: owner} = register_conn(conn)
    %{conn: other_conn} = register_conn(build_conn())
    matome = create_matome!(owner_conn)

    created = create_large_file!(owner_conn, matome)
    item = created["item"]

    upload = created["upload"]

    assert upload["mode"] == "multipart"
    assert upload["state"] == "uploading"
    assert upload["upload_generation"] == 1
    assert upload["part_size"] == 16 * 1024 * 1024
    assert upload["accepted_parts"] == []
    assert upload["missing_parts"] == [1, 2]
    refute Map.has_key?(upload, "request")

    assert post(owner_conn, "/api/items/#{item["id"]}/presign", %{})
           |> json_response(422) == %{"error" => "multipart_required"}

    blob = Repo.get!(FileBlob, item["file"]["id"])
    assert blob.storage_key =~ "owners/#{owner.id}/items/"
    assert blob.upload_state == "uploading"
    assert blob.multipart_context["provider_upload_id"]
    assert blob.multipart_context["upload_id"] == upload["upload_id"]

    provider_upload_id = blob.multipart_context["provider_upload_id"]

    Store.accept_part(store, provider_upload_id, %{
      part_number: 1,
      etag: "etag-1",
      checksum_sha256: @part_one_checksum,
      byte_size: 16 * 1024 * 1024
    })

    assert get(other_conn, "/api/v1/uploads/#{upload["upload_id"]}")
           |> json_response(404) == %{"error" => "not_found"}

    assert post(
             other_conn,
             "/api/v1/uploads/#{upload["upload_id"]}/parts/2/presign",
             %{"checksum_sha256" => @part_two_checksum}
           )
           |> json_response(404) == %{"error" => "not_found"}

    assert post(other_conn, "/api/v1/uploads/#{upload["upload_id"]}/complete", %{
             "upload_generation" => 1,
             "checksum_sha256" => @whole_checksum,
             "parts" => []
           })
           |> json_response(404) == %{"error" => "not_found"}

    assert post(other_conn, "/api/v1/uploads/#{upload["upload_id"]}/abort", %{
             "upload_generation" => 1
           })
           |> json_response(404) == %{"error" => "not_found"}

    resumed =
      post(owner_conn, "/api/v1/items/#{item["id"]}/uploads", %{
        "contract_version" => "1",
        "mode" => "auto"
      })
      |> json_response(200)
      |> Map.fetch!("upload")

    assert resumed["upload_id"] == upload["upload_id"]
    assert resumed["upload_generation"] == 1
    assert Enum.map(resumed["accepted_parts"], & &1["part_number"]) == [1]
    assert resumed["missing_parts"] == [2]
    assert Store.initiate_count(store) == 1

    policy_module = MatomeApi.Storage.UploadPolicy
    previous_policy = Application.get_env(:matome_api, policy_module)

    Application.put_env(
      :matome_api,
      policy_module,
      Keyword.put(previous_policy, :multipart_part_bytes, 8 * 1024 * 1024)
    )

    on_exit(fn -> Application.put_env(:matome_api, policy_module, previous_policy) end)

    part_request =
      post(
        owner_conn,
        "/api/v1/uploads/#{upload["upload_id"]}/parts/2/presign",
        %{"checksum_sha256" => @part_two_checksum}
      )
      |> json_response(200)
      |> Map.fetch!("part")

    assert part_request["part_number"] == 2
    assert part_request["byte_size"] == 14 * 1024 * 1024
    assert part_request["request"]["method"] == "PUT"

    assert part_request["request"]["headers"]["content-length"] ==
             to_string(14 * 1024 * 1024)

    Store.accept_part(store, provider_upload_id, %{
      part_number: 2,
      etag: "etag-2",
      checksum_sha256: @part_two_checksum,
      byte_size: 14 * 1024 * 1024
    })

    complete_body = %{
      "contract_version" => "1",
      "upload_generation" => 1,
      "checksum_sha256" => @whole_checksum,
      "parts" => [
        %{
          "part_number" => 1,
          "etag" => "etag-1",
          "checksum_sha256" => @part_one_checksum
        },
        %{
          "part_number" => 2,
          "etag" => "etag-2",
          "checksum_sha256" => @part_two_checksum
        }
      ]
    }

    completed =
      post(owner_conn, "/api/v1/uploads/#{upload["upload_id"]}/complete", complete_body)
      |> json_response(200)
      |> Map.fetch!("upload")

    assert completed["state"] == "uploaded"
    assert completed["verified_byte_size"] == @large_bytes
    assert completed["verified_checksum_sha256"] == @whole_checksum

    persisted = Repo.get!(FileBlob, blob.id)
    assert persisted.storage_key == blob.storage_key
    assert persisted.upload_state == "uploaded"
    assert persisted.uploaded_at
    assert persisted.multipart_context == nil

    replayed =
      post(owner_conn, "/api/v1/uploads/#{upload["upload_id"]}/complete", complete_body)
      |> json_response(200)

    assert replayed["upload"]["state"] == "uploaded"
    assert Store.complete_count(store) == 1

    assert post(owner_conn, "/api/items/#{item["id"]}/process", %{})
           |> json_response(202)
  end

  test "single completion verifies provider facts and failed verification blocks processing", %{
    conn: conn,
    store: store
  } do
    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    created = create_small_file!(owner_conn, matome, "single-ok", @whole_checksum)
    item = created["item"]

    requested =
      post(owner_conn, "/api/v1/items/#{item["id"]}/uploads", %{"mode" => "auto"})
      |> json_response(200)
      |> Map.fetch!("upload")

    assert requested["mode"] == "single"
    assert requested["request"]["headers"]["content-length"] == "1024"
    assert requested["request"]["headers"]["x-amz-checksum-sha256"]

    blob = Repo.get!(FileBlob, item["file"]["id"])

    Store.put_object(store, blob.storage_key, %{
      byte_size: 1024,
      checksum_sha256: @whole_checksum,
      etag: "etag-single"
    })

    assert post(owner_conn, "/api/v1/uploads/#{requested["upload_id"]}/complete", %{
             "upload_generation" => 1,
             "checksum_sha256" => @whole_checksum
           })
           |> json_response(422) == %{"error" => "etag_required"}

    assert post(owner_conn, "/api/v1/uploads/#{requested["upload_id"]}/complete", %{
             "upload_generation" => 1,
             "etag" => "etag-single",
             "checksum_sha256" => @whole_checksum
           })
           |> json_response(200)
           |> get_in(["upload", "state"]) == "uploaded"

    failed = create_small_file!(owner_conn, matome, "single-bad", @part_one_checksum)
    failed_item = failed["item"]

    failed_request =
      post(owner_conn, "/api/v1/items/#{failed_item["id"]}/uploads", %{"mode" => "auto"})
      |> json_response(200)
      |> Map.fetch!("upload")

    failed_blob = Repo.get!(FileBlob, failed_item["file"]["id"])

    Store.put_object(store, failed_blob.storage_key, %{
      byte_size: 1023,
      checksum_sha256: @part_one_checksum,
      etag: "etag-bad"
    })

    assert post(owner_conn, "/api/v1/uploads/#{failed_request["upload_id"]}/complete", %{
             "upload_generation" => 1,
             "etag" => "etag-bad",
             "checksum_sha256" => @part_one_checksum
           })
           |> json_response(422) == %{"error" => "verification_failed"}

    assert Repo.get!(FileBlob, failed_blob.id).upload_state == "failed"

    assert post(owner_conn, "/api/items/#{failed_item["id"]}/process", %{})
           |> json_response(422) == %{"error" => "upload_not_complete"}
  end

  test "browser single upload omits signed length and abandoned bytes are deleted", %{
    conn: conn,
    store: store
  } do
    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    created =
      create_small_file!(owner_conn, matome, "browser-single", @whole_checksum, %{
        "transport" => "browser_stream"
      })

    upload =
      post(owner_conn, "/api/v1/items/#{created["item"]["id"]}/uploads", %{
        "transport" => "browser_stream",
        "checksum_sha256" => @whole_checksum
      })
      |> json_response(200)
      |> Map.fetch!("upload")

    assert upload["transport"] == "browser_stream"
    refute Map.has_key?(upload["request"]["headers"], "content-length")
    assert upload["request"]["headers"]["x-amz-checksum-sha256"]

    blob = Repo.get!(FileBlob, created["item"]["file"]["id"])
    assert blob.multipart_context["mode"] == "single"
    assert blob.multipart_context["transport"] == "browser_stream"

    Store.put_object(store, blob.storage_key, %{
      byte_size: 1024,
      checksum_sha256: @whole_checksum,
      etag: "browser-etag"
    })

    expired_context = Map.put(blob.multipart_context, "expires_at", "2020-01-01T00:00:00Z")
    blob |> FileBlob.changeset(%{multipart_context: expired_context}) |> Repo.update!()

    assert :ok =
             UploadCleanupJob.perform(%Oban.Job{
               args: %{
                 "file_blob_id" => blob.id,
                 "upload_generation" => blob.upload_generation
               }
             })

    expired = Repo.get!(FileBlob, blob.id)
    assert expired.upload_state == "failed"
    assert expired.multipart_context == nil
    assert Store.object_count(store) == 0
  end

  test "completed browser single cleanup is a no-op", %{conn: conn, store: store} do
    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    created =
      create_small_file!(owner_conn, matome, "browser-complete", @whole_checksum, %{
        "transport" => "browser_stream"
      })

    upload =
      post(owner_conn, "/api/v1/items/#{created["item"]["id"]}/uploads", %{
        "transport" => "browser_stream",
        "checksum_sha256" => @whole_checksum
      })
      |> json_response(200)
      |> Map.fetch!("upload")

    blob = Repo.get!(FileBlob, created["item"]["file"]["id"])

    Store.put_object(store, blob.storage_key, %{
      byte_size: 1024,
      checksum_sha256: @whole_checksum,
      etag: "browser-etag"
    })

    completed =
      post(owner_conn, "/api/v1/uploads/#{upload["upload_id"]}/complete", %{
        "upload_generation" => upload["upload_generation"],
        "etag" => "browser-etag",
        "checksum_sha256" => @whole_checksum
      })
      |> json_response(200)
      |> Map.fetch!("upload")

    assert completed["state"] == "uploaded"
    assert completed["transport"] == "browser_stream"

    replayed =
      post(owner_conn, "/api/v1/uploads/#{upload["upload_id"]}/complete", %{
        "upload_generation" => upload["upload_generation"],
        "etag" => "browser-etag",
        "checksum_sha256" => @whole_checksum
      })
      |> json_response(200)
      |> Map.fetch!("upload")

    assert replayed["transport"] == "browser_stream"

    assert :ok =
             UploadCleanupJob.perform(%Oban.Job{
               args: %{
                 "file_blob_id" => blob.id,
                 "upload_generation" => blob.upload_generation
               }
             })

    assert Repo.get!(FileBlob, blob.id).upload_state == "uploaded"
    assert Store.object_count(store) == 1
  end

  test "upload transport is validated and cannot change within a generation", %{conn: conn} do
    %{conn: owner_conn, user: owner} = register_conn(conn)
    matome = create_matome!(owner_conn)
    created = create_small_file!(owner_conn, matome, "transport-lock", @whole_checksum)
    item = created["item"]

    assert post(owner_conn, "/api/v1/items/#{item["id"]}/uploads", %{
             "transport" => "direct_signed_length"
           })
           |> json_response(200)
           |> get_in(["upload", "transport"]) == "direct_signed_length"

    assert post(owner_conn, "/api/v1/items/#{item["id"]}/uploads", %{
             "transport" => "unknown"
           })
           |> json_response(422) == %{"error" => "invalid_upload_transport"}

    assert post(owner_conn, "/api/v1/items/#{item["id"]}/uploads", %{
             "transport" => "browser_stream",
             "checksum_sha256" => @whole_checksum
           })
           |> json_response(422) == %{"error" => "upload_transport_mismatch"}

    {:ok, missing_checksum} =
      Content.create_file_item(owner, matome["id"], %{
        client_id: "browser-needs-checksum",
        byte_size: 1024,
        media_type: "audio"
      })

    assert post(owner_conn, "/api/v1/items/#{missing_checksum.id}/uploads", %{
             "transport" => "browser_stream"
           })
           |> json_response(422) == %{"error" => "checksum_required"}
  end

  test "browser multipart persists transport and omits per-part signed length", %{
    conn: conn
  } do
    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    created =
      create_large_file!(owner_conn, matome, "browser-multipart", %{
        "transport" => "browser_stream"
      })

    upload = created["upload"]
    assert upload["transport"] == "browser_stream"

    blob = Repo.get!(FileBlob, created["item"]["file"]["id"])
    assert blob.multipart_context["transport"] == "browser_stream"

    part =
      post(owner_conn, "/api/v1/uploads/#{upload["upload_id"]}/parts/1/presign", %{
        "checksum_sha256" => @part_one_checksum
      })
      |> json_response(200)
      |> Map.fetch!("part")

    refute Map.has_key?(part["request"]["headers"], "content-length")
    assert part["request"]["headers"]["x-amz-checksum-sha256"]
  end

  test "image upload records its declared content type before capability dispatch", %{
    conn: conn,
    store: store
  } do
    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    created =
      post(owner_conn, "/api/matomes/#{matome["id"]}/items", %{
        "client_id" => "image-content-type",
        "item_type" => "file",
        "title" => "Launch board",
        "filename" => "launch-board.png",
        "byte_size" => 1024,
        "checksum_sha256" => @whole_checksum,
        "media_type" => "image"
      })
      |> json_response(201)

    item = created["item"]

    requested =
      post(owner_conn, "/api/v1/items/#{item["id"]}/uploads", %{
        "contract_version" => "1",
        "mode" => "auto",
        "content_type" => "image/png",
        "checksum_sha256" => @whole_checksum
      })
      |> json_response(200)
      |> Map.fetch!("upload")

    blob = Repo.get!(FileBlob, item["file"]["id"])
    assert blob.content_type == "image/png"

    assert post(owner_conn, "/api/v1/items/#{item["id"]}/uploads", %{
             "contract_version" => "1",
             "mode" => "auto",
             "content_type" => "image/jpeg",
             "checksum_sha256" => @whole_checksum
           })
           |> json_response(422) == %{"error" => "content_type_mismatch"}

    Store.put_object(store, blob.storage_key, %{
      byte_size: 1024,
      checksum_sha256: @whole_checksum,
      etag: "etag-image"
    })

    assert post(owner_conn, "/api/v1/uploads/#{requested["upload_id"]}/complete", %{
             "upload_generation" => requested["upload_generation"],
             "etag" => "etag-image",
             "checksum_sha256" => @whole_checksum
           })
           |> json_response(200)
           |> get_in(["upload", "state"]) == "uploaded"

    queued =
      post(owner_conn, "/api/items/#{item["id"]}/process", %{})
      |> json_response(202)
      |> Map.fetch!("item")

    assert queued["processing_state"] == "queued"

    assert MapSet.new(queued["processing_requested_outputs"]) ==
             MapSet.new(~w(ocr_text description summary title))
  end

  test "document completion normalizes MIME and downgrades a mismatched signature", %{
    conn: conn,
    store: store
  } do
    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    created =
      post(owner_conn, "/api/matomes/#{matome["id"]}/items", %{
        "item_type" => "file",
        "filename" => "report.pdf",
        "content_type" => "application/pdf",
        "byte_size" => 1024,
        "checksum_sha256" => @whole_checksum,
        "media_type" => "document"
      })
      |> json_response(201)

    item = created["item"]

    requested =
      post(owner_conn, "/api/v1/items/#{item["id"]}/uploads", %{
        "mode" => "auto",
        "content_type" => " Application/PDF ; charset=binary "
      })
      |> json_response(200)
      |> Map.fetch!("upload")

    blob = Repo.get!(FileBlob, item["file"]["id"])
    assert blob.content_type == "application/pdf"

    Store.put_object(store, blob.storage_key, %{
      byte_size: 1024,
      checksum_sha256: @whole_checksum,
      etag: "etag-document",
      body: "plain text pretending to be a PDF"
    })

    assert post(owner_conn, "/api/v1/uploads/#{requested["upload_id"]}/complete", %{
             "upload_generation" => requested["upload_generation"],
             "etag" => "etag-document",
             "checksum_sha256" => @whole_checksum
           })
           |> json_response(200)
           |> get_in(["upload", "state"]) == "uploaded"

    assert Repo.get!(FileBlob, blob.id).open_policy == "download_only"
  end

  test "multipart abort and expiry cleanup leave no provider upload", %{conn: conn, store: store} do
    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    first = create_large_file!(owner_conn, matome, "abort-me")
    first_upload = first["upload"]

    assert post(owner_conn, "/api/v1/uploads/#{first_upload["upload_id"]}/abort", %{
             "upload_generation" => 1,
             "reason" => "user_cancelled"
           })
           |> json_response(200)
           |> get_in(["upload", "state"]) == "aborted"

    assert post(owner_conn, "/api/v1/uploads/#{first_upload["upload_id"]}/abort", %{
             "upload_generation" => 1,
             "reason" => "user_cancelled"
           })
           |> json_response(200)
           |> get_in(["upload", "state"]) == "aborted"

    assert Store.active_upload_count(store) == 0
    assert Store.abort_count(store) == 1

    assert post(owner_conn, "/api/v1/uploads/#{first_upload["upload_id"]}/complete", %{
             "upload_generation" => 1,
             "checksum_sha256" => @whole_checksum,
             "parts" => []
           })
           |> json_response(422) == %{"error" => "upload_not_active"}

    first_blob = Repo.get!(FileBlob, first["item"]["file"]["id"])

    retried =
      post(owner_conn, "/api/v1/items/#{first["item"]["id"]}/uploads", %{"mode" => "auto"})
      |> json_response(200)
      |> Map.fetch!("upload")

    assert retried["upload_generation"] == 2
    assert Repo.get!(FileBlob, first_blob.id).storage_key == first_blob.storage_key

    assert post(owner_conn, "/api/v1/uploads/#{first_upload["upload_id"]}/abort", %{
             "upload_generation" => 1
           })
           |> json_response(200)
           |> get_in(["upload", "state"]) == "stale"

    assert Store.active_upload_count(store) == 1

    assert post(owner_conn, "/api/v1/uploads/#{retried["upload_id"]}/abort", %{
             "upload_generation" => 2
           })
           |> json_response(200)

    assert Store.active_upload_count(store) == 0
    assert Store.abort_count(store) == 2

    second = create_large_file!(owner_conn, matome, "expire-me")
    second_blob = Repo.get!(FileBlob, second["item"]["file"]["id"])
    context = Map.put(second_blob.multipart_context, "expires_at", "2020-01-01T00:00:00Z")

    second_blob
    |> FileBlob.changeset(%{multipart_context: context})
    |> Repo.update!()

    assert :ok =
             UploadCleanupJob.perform(%Oban.Job{
               args: %{
                 "file_blob_id" => second_blob.id,
                 "upload_generation" => second_blob.upload_generation
               }
             })

    expired = Repo.get!(FileBlob, second_blob.id)
    assert expired.upload_state == "failed"
    assert expired.multipart_context == nil
    assert Store.active_upload_count(store) == 0
  end

  test "large uploads enforce Space quota before creating provider state", %{
    conn: conn,
    store: store
  } do
    %{conn: owner_conn, user: owner} = register_conn(conn)
    {:ok, workspace} = Content.create_workspace(owner, %{name: "Bounded"})

    workspace
    |> Workspace.admin_changeset(%{quota_bytes: @large_bytes - 1})
    |> Repo.update!()

    matome = create_matome!(owner_conn, %{workspace_id: workspace.id})

    assert post(owner_conn, "/api/matomes/#{matome["id"]}/items", %{
             "client_id" => "over-space-quota",
             "item_type" => "file",
             "checksum_sha256" => @whole_checksum,
             "byte_size" => @large_bytes,
             "media_type" => "audio"
           })
           |> json_response(413) == %{"error" => "quota_exceeded"}

    assert Store.initiate_count(store) == 0
    assert Repo.get!(Workspace, workspace.id).used_bytes == 0
  end

  test "multipart creation requires a checksum before provider state", %{conn: conn, store: store} do
    %{conn: owner_conn} = register_conn(conn)
    matome = create_matome!(owner_conn)

    response =
      post(owner_conn, "/api/matomes/#{matome["id"]}/items", %{
        "client_id" => "missing-multipart-checksum",
        "item_type" => "file",
        "byte_size" => @large_bytes,
        "media_type" => "audio"
      })
      |> json_response(422)

    assert response["errors"]["checksum_sha256"] == ["is required for multipart upload"]
    assert Store.initiate_count(store) == 0
    assert Repo.aggregate(FileBlob, :count, :id) == 0
  end

  defmodule Store do
    def initial_state do
      %{next: 1, uploads: %{}, objects: %{}, initiate_count: 0, complete_count: 0, abort_count: 0}
    end

    def initiate_multipart(storage_key, opts, store) do
      Agent.get_and_update(store, fn state ->
        id = "provider-#{state.next}"
        upload = %{storage_key: storage_key, opts: Map.new(opts), parts: %{}}

        {{:ok, %{upload_id: id}},
         %{
           state
           | next: state.next + 1,
             initiate_count: state.initiate_count + 1,
             uploads: Map.put(state.uploads, id, upload)
         }}
      end)
    end

    def presign_part(_storage_key, upload_id, part_number, opts, _store) do
      headers = %{"x-amz-checksum-sha256" => opts[:checksum_sha256]}

      headers =
        if opts[:content_length],
          do: Map.put(headers, "content-length", to_string(opts[:content_length])),
          else: headers

      {:ok,
       %{
         method: "PUT",
         url: "https://storage.invalid/#{upload_id}/#{part_number}",
         headers: headers,
         expires_in: 900,
         expires_at: DateTime.add(DateTime.utc_now(), 900, :second)
       }}
    end

    def list_parts(_storage_key, upload_id, store) do
      Agent.get(store, fn state ->
        case state.uploads[upload_id] do
          nil -> {:error, :no_such_upload}
          upload -> {:ok, upload.parts |> Map.values() |> Enum.sort_by(& &1.part_number)}
        end
      end)
    end

    def complete_multipart(_storage_key, upload_id, _parts, store) do
      Agent.get_and_update(store, fn state ->
        case Map.pop(state.uploads, upload_id) do
          {nil, _uploads} ->
            {{:error, :no_such_upload}, state}

          {upload, uploads} ->
            object = %{
              byte_size: upload.opts[:byte_size],
              checksum_sha256: upload.opts[:checksum_sha256],
              etag: "etag-complete"
            }

            {:ok,
             %{
               state
               | uploads: uploads,
                 objects: Map.put(state.objects, upload.storage_key, object),
                 complete_count: state.complete_count + 1
             }}
        end
      end)
    end

    def abort_multipart(_storage_key, upload_id, store) do
      Agent.update(store, fn state ->
        if Map.has_key?(state.uploads, upload_id) do
          %{
            state
            | uploads: Map.delete(state.uploads, upload_id),
              abort_count: state.abort_count + 1
          }
        else
          state
        end
      end)

      :ok
    end

    def head_object(storage_key, store) do
      Agent.get(store, fn state ->
        case state.objects[storage_key] do
          nil -> {:error, :not_found}
          object -> {:ok, object}
        end
      end)
    end

    def get_prefix(storage_key, max_bytes, store) do
      Agent.get(store, fn state ->
        case state.objects[storage_key] do
          nil ->
            {:error, :not_found}

          object ->
            {:ok,
             object
             |> Map.get(:body, "")
             |> binary_part(0, min(byte_size(Map.get(object, :body, "")), max_bytes))}
        end
      end)
    end

    def delete_object(storage_key, store) do
      Agent.update(store, fn state ->
        %{state | objects: Map.delete(state.objects, storage_key)}
      end)

      :ok
    end

    def accept_part(store, upload_id, part) do
      Agent.update(store, fn state ->
        update_in(state, [:uploads, upload_id, :parts], &Map.put(&1, part.part_number, part))
      end)
    end

    def put_object(store, storage_key, object) do
      Agent.update(store, &put_in(&1, [:objects, storage_key], object))
    end

    def initiate_count(store), do: Agent.get(store, & &1.initiate_count)
    def complete_count(store), do: Agent.get(store, & &1.complete_count)
    def abort_count(store), do: Agent.get(store, & &1.abort_count)
    def active_upload_count(store), do: Agent.get(store, &map_size(&1.uploads))
    def object_count(store), do: Agent.get(store, &map_size(&1.objects))
  end

  defp create_large_file!(conn, matome, client_id \\ "large-audio", attrs \\ %{}) do
    params = %{
      "client_id" => client_id,
      "item_type" => "file",
      "title" => client_id,
      "filename" => "#{client_id}.wav",
      "content_type" => "audio/wav",
      "checksum_sha256" => @whole_checksum,
      "byte_size" => @large_bytes,
      "media_type" => "audio"
    }

    post(conn, "/api/matomes/#{matome["id"]}/items", Map.merge(params, attrs))
    |> json_response(201)
  end

  defp create_small_file!(conn, matome, client_id, checksum, attrs \\ %{}) do
    params = %{
      "client_id" => client_id,
      "item_type" => "file",
      "checksum_sha256" => checksum,
      "byte_size" => 1024,
      "media_type" => "audio"
    }

    post(conn, "/api/matomes/#{matome["id"]}/items", Map.merge(params, attrs))
    |> json_response(201)
  end

  defp create_matome!(conn, attrs \\ %{}) do
    post(conn, "/api/matomes", Map.put(attrs, :title, "Upload lifecycle"))
    |> json_response(201)
    |> Map.fetch!("matome")
  end

  defp register_conn(conn) do
    email = "upload-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, %{user: user, access_token: token}} =
             Auth.register_user(%{email: email, password: @password})

    %{conn: put_req_header(conn, "authorization", "Bearer #{token}"), user: user}
  end
end
