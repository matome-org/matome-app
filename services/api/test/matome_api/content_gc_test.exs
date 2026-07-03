defmodule MatomeApi.ContentGcTest do
  use MatomeApi.DataCase, async: false

  alias MatomeApi.Auth
  alias MatomeApi.Content
  alias MatomeApi.Content.{FileBlob, TextContent}

  @password "correct horse battery staple"

  test "sweep_orphaned_payloads reaps unreferenced rows + storage, keeps referenced ones" do
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

    owner = user_fixture()
    assert {:ok, matome} = Content.create_matome(owner, %{title: "GC"})

    # A referenced payload — must survive the sweep.
    assert {:ok, item} =
             Content.create_file_item(owner, matome.id, %{media_type: "audio", byte_size: 10})

    referenced_blob_id = item.file_blob_id

    orphan_key = "owners/#{owner.id}/items/orphan-blob"

    assert {:ok, orphan_blob} =
             %FileBlob{}
             |> FileBlob.changeset(%{
               storage_key: orphan_key,
               byte_size: 5,
               media_type: "audio"
             })
             |> Repo.insert()

    assert {:ok, orphan_text} =
             %TextContent{}
             |> TextContent.changeset(%{body: "loose text"})
             |> Repo.insert()

    assert {:ok, result} = Content.sweep_orphaned_payloads()

    assert orphan_blob.id in result.file_blob_ids
    refute referenced_blob_id in result.file_blob_ids
    assert orphan_text.id in result.text_content_ids
    assert orphan_key in result.storage_keys

    assert Repo.get(FileBlob, orphan_blob.id) == nil
    assert Repo.get(TextContent, orphan_text.id) == nil
    assert Repo.get(FileBlob, referenced_blob_id)

    assert_receive {:delete_object, ^orphan_key}
  end

  defmodule ObjectStore do
    def delete_object(storage_key, parent) do
      send(parent, {:delete_object, storage_key})
      :ok
    end
  end

  defp user_fixture do
    email = "user-#{System.unique_integer([:positive])}@example.com"
    assert {:ok, %{user: user}} = Auth.register_user(%{email: email, password: @password})
    user
  end
end
