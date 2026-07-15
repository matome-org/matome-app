defmodule MatomeApi.Repo.ItemsSchemaTest do
  use MatomeApi.DataCase, async: true

  alias MatomeApi.Repo

  test "recordings table is gone and item payload tables exist" do
    assert table_exists?("items")
    assert table_exists?("file_blobs")
    assert table_exists?("text_contents")
    refute table_exists?("recordings")
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

  defp insert_matome!(owner_id) do
    %{rows: [[id]]} =
      Repo.query!(
        "INSERT INTO matomes (owner_id, title, inserted_at, updated_at) VALUES ($1, 'Schema', now(), now()) RETURNING id",
        [owner_id]
      )

    id
  end

  defp insert_file_blob!(media_type \\ "audio") do
    %{rows: [[id]]} =
      Repo.query!(
        """
        INSERT INTO file_blobs (storage_key, byte_size, media_type, inserted_at, updated_at)
        VALUES ($1, 123, $2, now(), now()) RETURNING id
        """,
        ["objects/#{System.unique_integer([:positive])}", media_type]
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
