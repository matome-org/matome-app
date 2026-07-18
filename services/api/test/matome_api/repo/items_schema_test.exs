defmodule MatomeApi.Repo.ItemsSchemaTest do
  use MatomeApi.DataCase, async: true

  alias MatomeApi.Repo

  test "recordings table is gone and item payload tables exist" do
    assert table_exists?("items")
    assert table_exists?("file_blobs")
    assert table_exists?("text_contents")
    refute table_exists?("recordings")
    refute table_exists?("processing_attempts")
    refute table_exists?("derivations")
    refute table_exists?("upload_sessions")
  end

  test "items and file blobs expose the canonical current-state columns" do
    assert columns("items") >=
             MapSet.new(~w(
               owner_id client_id workspace_id matome_id title notes item_type metadata
               processing_state processing_run_id processing_attempt source_revision
               processing_config_revision processing_capabilities processing_requested_outputs
               processing_requested_at processing_deadline_at
               processing_outputs processing_error file_blob_id text_content_id
             ))

    assert columns("file_blobs") >=
             MapSet.new(~w(
               storage_key filename content_type byte_size checksum_sha256 media_type duration
               upload_state upload_generation uploaded_at multipart_context
             ))
  end

  test "matomes expose owner-scoped permanent client identity" do
    assert columns("matomes") >= MapSet.new(~w(client_id client_fingerprint))

    owner = user_fixture()

    Repo.query!(
      "INSERT INTO matomes (owner_id, client_id, client_fingerprint, title, inserted_at, updated_at) VALUES ($1, $2, $3, 'One', now(), now())",
      [owner.id, "matome-local", String.duplicate("a", 64)]
    )

    assert_raise Postgrex.Error, ~r/matomes_owner_id_client_id_index/, fn ->
      Repo.query!(
        "INSERT INTO matomes (owner_id, client_id, client_fingerprint, title, inserted_at, updated_at) VALUES ($1, $2, $3, 'Two', now(), now())",
        [owner.id, "matome-local", String.duplicate("b", 64)]
      )
    end

    assert_raise Postgrex.Error, ~r/matomes_client_identity_check/, fn ->
      Repo.query!(
        "INSERT INTO matomes (owner_id, client_id, title, inserted_at, updated_at) VALUES ($1, 'missing-fingerprint', 'Invalid', now(), now())",
        [owner.id]
      )
    end
  end

  test "items enforce one payload matching item_type" do
    user = user_fixture()
    matome_id = insert_matome!(user.id)
    file_blob_id = insert_file_blob!()
    text_content_id = insert_text_content!()

    assert_raise Postgrex.Error, ~r/items_payload_exclusive_arc_check/, fn ->
      insert_item!(matome_id, 1, "text", nil, nil)
    end

    assert_raise Postgrex.Error, ~r/items_payload_exclusive_arc_check/, fn ->
      insert_item!(matome_id, 2, "text", file_blob_id, text_content_id)
    end

    assert_raise Postgrex.Error, ~r/items_payload_exclusive_arc_check/, fn ->
      insert_item!(matome_id, 3, "text", file_blob_id, nil)
    end
  end

  test "items have a unique matome position index" do
    user = user_fixture()
    matome_id = insert_matome!(user.id)
    first_text_id = insert_text_content!("first")
    second_text_id = insert_text_content!("second")

    insert_item!(matome_id, 1, "text", nil, first_text_id)

    assert_raise Postgrex.Error, ~r/items_matome_id_position_index/, fn ->
      insert_item!(matome_id, 1, "text", nil, second_text_id)
    end
  end

  test "items allow loose, direct-workspace, and shadowed Matome placement" do
    user = user_fixture()
    workspace_id = insert_workspace!(user.id)
    matome_id = insert_matome!(user.id)

    loose_id = insert_text_item_for_owner!(user.id)
    direct_id = insert_text_item_for_owner!(user.id, workspace_id: workspace_id)

    shadowed_id =
      insert_text_item_for_owner!(user.id,
        workspace_id: workspace_id,
        matome_id: matome_id,
        position: 0
      )

    assert %{rows: [[nil, nil, nil]]} =
             Repo.query!("SELECT workspace_id, matome_id, position FROM items WHERE id = $1", [
               loose_id
             ])

    assert %{rows: [[^workspace_id, nil, nil]]} =
             Repo.query!("SELECT workspace_id, matome_id, position FROM items WHERE id = $1", [
               direct_id
             ])

    assert %{rows: [[^workspace_id, ^matome_id, 0]]} =
             Repo.query!("SELECT workspace_id, matome_id, position FROM items WHERE id = $1", [
               shadowed_id
             ])
  end

  test "item placement foreign keys enforce owner isolation" do
    owner = user_fixture()
    other_owner = user_fixture()
    other_workspace_id = insert_workspace!(other_owner.id)
    other_matome_id = insert_matome!(other_owner.id)

    assert_raise Postgrex.Error, ~r/items_owner_workspace_fkey/, fn ->
      insert_text_item_for_owner!(owner.id, workspace_id: other_workspace_id)
    end

    assert_raise Postgrex.Error, ~r/items_owner_matome_fkey/, fn ->
      insert_text_item_for_owner!(owner.id, matome_id: other_matome_id, position: 0)
    end
  end

  test "client ids are unique per owner and independent between owners" do
    first_owner = user_fixture()
    second_owner = user_fixture()

    insert_text_item_for_owner!(first_owner.id,
      client_id: "rec_local_shared",
      client_fingerprint: String.duplicate("a", 64)
    )

    assert_raise Postgrex.Error, ~r/items_owner_id_client_id_index/, fn ->
      insert_text_item_for_owner!(first_owner.id,
        client_id: "rec_local_shared",
        client_fingerprint: String.duplicate("a", 64)
      )
    end

    insert_text_item_for_owner!(second_owner.id,
      client_id: "rec_local_shared",
      client_fingerprint: String.duplicate("b", 64)
    )
  end

  test "file upload facts enforce checksums, current generation, and uploaded timestamp" do
    assert_raise Postgrex.Error, ~r/file_blobs_checksum_sha256_check/, fn ->
      insert_file_blob!("audio", checksum_sha256: "not-sha256")
    end

    assert_raise Postgrex.Error, ~r/file_blobs_upload_generation_check/, fn ->
      insert_file_blob!("audio", upload_generation: 0)
    end

    assert_raise Postgrex.Error, ~r/file_blobs_uploaded_at_check/, fn ->
      insert_file_blob!("audio", upload_state: "uploaded")
    end

    assert_raise Postgrex.Error, ~r/file_blobs_uploaded_at_check/, fn ->
      insert_file_blob!("audio", uploaded_at: DateTime.utc_now())
    end

    assert_raise Postgrex.Error, ~r/file_blobs_uploaded_at_check/, fn ->
      insert_file_blob!("audio",
        upload_state: "uploaded",
        uploaded_at: DateTime.utc_now()
      )
    end

    insert_file_blob!("audio",
      checksum_sha256: String.duplicate("a", 64),
      upload_state: "uploaded",
      uploaded_at: DateTime.utc_now()
    )
  end

  test "current processing and multipart JSONB are type and size bounded" do
    user = user_fixture()
    run_id = Ecto.UUID.generate()

    assert_raise Postgrex.Error, ~r/items_processing_run_check/, fn ->
      insert_text_item_for_owner!(user.id, processing_state: "queued")
    end

    assert_raise Postgrex.Error, ~r/items_processing_run_check/, fn ->
      insert_text_item_for_owner!(user.id,
        processing_outputs: %{"summary" => %{"markdown" => "stale"}}
      )
    end

    insert_text_item_for_owner!(user.id,
      processing_state: "queued",
      processing_run_id: Ecto.UUID.generate(),
      processing_outputs: %{"summary" => %{"markdown" => "prior retry output"}}
    )

    assert_raise Postgrex.Error, ~r/items_processing_outputs_check/, fn ->
      insert_text_item_for_owner!(user.id,
        processing_state: "queued",
        processing_run_id: run_id,
        processing_outputs: %{"text" => String.duplicate("x", 4_194_304)}
      )
    end

    assert_raise Postgrex.Error, ~r/items_processing_error_check/, fn ->
      insert_text_item_for_owner!(user.id,
        processing_state: "failed",
        processing_run_id: run_id,
        processing_error: %{"message" => String.duplicate("x", 16_384)}
      )
    end

    assert_raise Postgrex.Error, ~r/items_processing_capabilities_check/, fn ->
      insert_text_item_for_owner!(user.id,
        processing_state: "queued",
        processing_run_id: run_id,
        processing_capabilities: %{"text" => String.duplicate("x", 65_536)}
      )
    end

    assert_raise Postgrex.Error, ~r/items_processing_requested_outputs_check/, fn ->
      insert_text_item_for_owner!(user.id,
        processing_state: "queued",
        processing_run_id: run_id,
        processing_requested_outputs: ["arbitrary_json"]
      )
    end

    assert_raise Postgrex.Error, ~r/file_blobs_multipart_context_check/, fn ->
      insert_file_blob!("audio",
        multipart_context: %{"provider" => String.duplicate("x", 262_144)}
      )
    end

    insert_text_item_for_owner!(user.id,
      processing_state: "failed",
      processing_run_id: run_id,
      processing_error: %{"code" => "processor_unavailable", "retryable" => true}
    )

    insert_text_item_for_owner!(user.id,
      processing_state: "partial",
      processing_run_id: Ecto.UUID.generate(),
      processing_outputs: %{"summary" => %{"type" => "summary", "markdown" => "partial"}}
    )

    insert_text_item_for_owner!(user.id,
      processing_state: "not_available",
      processing_run_id: Ecto.UUID.generate(),
      processing_requested_outputs: []
    )

    insert_file_blob!("audio",
      upload_state: "uploading",
      multipart_context: %{"upload_id" => "provider-upload-1", "parts" => []}
    )
  end

  test "file blobs restrict media_type to supported classes" do
    insert_file_blob!("audio")
    insert_file_blob!("image")
    insert_file_blob!("document")
    insert_file_blob!("video")

    assert_raise Postgrex.Error, ~r/file_blobs_media_type_check/, fn ->
      insert_file_blob!("meeting")
    end
  end

  defp table_exists?(table) do
    %{rows: [[count]]} =
      Repo.query!(
        "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name = $1",
        [table]
      )

    count == 1
  end

  defp columns(table) do
    %{rows: rows} =
      Repo.query!(
        "SELECT column_name FROM information_schema.columns WHERE table_schema = 'public' AND table_name = $1",
        [table]
      )

    rows |> List.flatten() |> MapSet.new()
  end

  defp insert_matome!(owner_id) do
    %{rows: [[id]]} =
      Repo.query!(
        "INSERT INTO matomes (owner_id, title, inserted_at, updated_at) VALUES ($1, 'Schema', now(), now()) RETURNING id",
        [owner_id]
      )

    id
  end

  defp insert_workspace!(owner_id) do
    %{rows: [[id]]} =
      Repo.query!(
        "INSERT INTO workspaces (owner_id, name, inserted_at, updated_at) VALUES ($1, $2, now(), now()) RETURNING id",
        [owner_id, "Schema #{System.unique_integer([:positive])}"]
      )

    id
  end

  defp insert_file_blob!(media_type \\ "audio", attrs \\ []) do
    filename = if media_type == "document", do: "schema.pdf"
    original_extension = if media_type == "document", do: "pdf"
    content_type = if media_type == "document", do: "application/pdf"
    open_policy = if media_type == "document", do: "external", else: "download_only"
    checksum_sha256 = Keyword.get(attrs, :checksum_sha256)
    upload_state = Keyword.get(attrs, :upload_state, "pending")
    upload_generation = Keyword.get(attrs, :upload_generation, 1)
    uploaded_at = Keyword.get(attrs, :uploaded_at)
    multipart_context = Keyword.get(attrs, :multipart_context)

    %{rows: [[id]]} =
      Repo.query!(
        """
        INSERT INTO file_blobs (
          storage_key, filename, original_extension, content_type, byte_size, media_type,
          checksum_sha256, upload_state, upload_generation, uploaded_at, multipart_context,
          open_policy, inserted_at, updated_at
        )
        VALUES ($1, $2, $3, $4, 123, $5, $6, $7, $8, $9, $10::jsonb, $11, now(), now())
        RETURNING id
        """,
        [
          "objects/#{System.unique_integer([:positive])}",
          filename,
          original_extension,
          content_type,
          media_type,
          checksum_sha256,
          upload_state,
          upload_generation,
          uploaded_at,
          multipart_context,
          open_policy
        ]
      )

    id
  end

  defp insert_text_content!(body \\ "hello") do
    %{rows: [[id]]} =
      Repo.query!(
        "INSERT INTO text_contents (body, inserted_at, updated_at) VALUES ($1, now(), now()) RETURNING id",
        [body]
      )

    id
  end

  defp insert_text_item_for_owner!(owner_id, attrs \\ []) do
    text_content_id = insert_text_content!("body-#{System.unique_integer([:positive])}")
    workspace_id = Keyword.get(attrs, :workspace_id)
    matome_id = Keyword.get(attrs, :matome_id)
    position = Keyword.get(attrs, :position)
    client_id = Keyword.get(attrs, :client_id)
    client_fingerprint = Keyword.get(attrs, :client_fingerprint)
    processing_state = Keyword.get(attrs, :processing_state, "not_requested")

    processing_run_id =
      case Keyword.get(attrs, :processing_run_id) do
        nil -> nil
        run_id -> run_id |> Ecto.UUID.dump() |> elem(1)
      end

    processing_outputs = Keyword.get(attrs, :processing_outputs, %{})
    processing_error = Keyword.get(attrs, :processing_error)

    processing_attempt =
      Keyword.get(attrs, :processing_attempt, if(processing_run_id, do: 1, else: 0))

    processing_config_revision =
      Keyword.get(attrs, :processing_config_revision, if(processing_run_id, do: 1, else: nil))

    processing_capabilities =
      Keyword.get(
        attrs,
        :processing_capabilities,
        if(processing_run_id,
          do: %{
            "contract_version" => "1",
            "service" => "schema-test",
            "input_kind" => "text",
            "input" => %{
              "enabled" => true,
              "max_characters" => 200_000,
              "outputs" => ~w(summary title)
            }
          },
          else: nil
        )
      )

    processing_requested_outputs =
      Keyword.get(
        attrs,
        :processing_requested_outputs,
        if(processing_run_id, do: ~w(summary title), else: [])
      )

    processing_requested_at = if processing_run_id, do: DateTime.utc_now(), else: nil

    processing_deadline_at =
      if processing_run_id, do: DateTime.add(DateTime.utc_now(), 60), else: nil

    %{rows: [[id]]} =
      Repo.query!(
        """
        INSERT INTO items (
          owner_id, client_id, client_fingerprint, workspace_id, matome_id, position,
          item_type, title, metadata, processing_state, processing_run_id,
          processing_attempt, processing_config_revision, processing_capabilities,
          processing_requested_outputs, processing_requested_at, processing_deadline_at,
          processing_outputs, processing_error, text_content_id, inserted_at, updated_at
        )
        VALUES (
          $1, $2, $3, $4, $5, $6, 'text', 'Schema item', '{}'::jsonb, $7, $8,
          $9, $10, $11::jsonb, $12, $13, $14, $15::jsonb, $16::jsonb, $17, now(), now()
        )
        RETURNING id
        """,
        [
          owner_id,
          client_id,
          client_fingerprint,
          workspace_id,
          matome_id,
          position,
          processing_state,
          processing_run_id,
          processing_attempt,
          processing_config_revision,
          processing_capabilities,
          processing_requested_outputs,
          processing_requested_at,
          processing_deadline_at,
          processing_outputs,
          processing_error,
          text_content_id
        ]
      )

    id
  end

  defp insert_item!(matome_id, position, item_type, file_blob_id, text_content_id) do
    Repo.query!(
      """
      INSERT INTO items (owner_id, matome_id, position, item_type, metadata, file_blob_id, text_content_id, inserted_at, updated_at)
      SELECT owner_id, id, $2, $3, '{}'::jsonb, $4, $5, now(), now()
      FROM matomes WHERE id = $1
      """,
      [matome_id, position, item_type, file_blob_id, text_content_id]
    )
  end

  defp user_fixture do
    email = "user-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, %{user: user}} =
             MatomeApi.Auth.register_user(%{
               email: email,
               password: "correct horse battery staple"
             })

    user
  end
end
