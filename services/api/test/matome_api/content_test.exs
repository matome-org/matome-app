defmodule MatomeApi.ContentTest do
  use MatomeApi.DataCase, async: true

  alias MatomeApi.Auth
  alias MatomeApi.Content

  @password "correct horse battery staple"

  test "text items are scoped by matome owner and delete their payload" do
    owner = user_fixture()
    other_owner = user_fixture()
    assert {:ok, matome} = Content.create_matome(owner, %{title: "Kickoff"})

    assert {:ok, item} =
             Content.create_text_item(owner, matome.id, %{
               position: 1,
               body: "Meeting notes",
               metadata: %{"display" => "note-card"}
             })

    assert item.item_type == :text
    assert item.position == 1
    assert item.metadata == %{"display" => "note-card"}
    assert item.matome_id == matome.id
    assert item.text_content.body == "Meeting notes"
    assert Content.get_item(owner, item.id).id == item.id
    assert Content.get_item(other_owner, item.id) == nil
    assert Content.list_items(owner, matome.id) |> Enum.map(& &1.id) == [item.id]
    assert Content.list_items(other_owner, matome.id) == nil
    assert Content.presign_item_upload(other_owner, item.id) == nil
    assert Content.delete_item(other_owner, item.id) == nil
    assert {:error, :text_item_not_presignable} = Content.presign_item_upload(owner, item.id)

    text_content_id = item.text_content_id
    assert {:ok, _} = Content.delete_item(owner, item.id)
    assert MatomeApi.Repo.get(MatomeApi.Content.TextContent, text_content_id) == nil
  end

  test "file items are scoped by matome owner and delete their payload" do
    owner = user_fixture()
    other_owner = user_fixture()
    assert {:ok, matome} = Content.create_matome(owner, %{title: "Kickoff"})

    assert {:ok, item} =
             Content.create_file_item(owner, matome.id, %{
               position: 1,
               storage_key: "owners/#{owner.id}/items/audio.wav",
               byte_size: 42,
               media_type: "audio",
               duration: 10,
               transcript: "hello",
               summary: "short"
             })

    assert item.item_type == :file
    assert item.file_blob.media_type == "audio"
    assert Content.get_item(other_owner, item.id) == nil
    assert Content.presign_item_upload(other_owner, item.id) == nil
    assert Content.delete_item(other_owner, item.id) == nil
    assert {:ok, presign} = Content.presign_item_upload(owner, item.id)
    assert presign.storage_key == item.file_blob.storage_key
    file_blob_id = item.file_blob_id
    assert {:ok, _} = Content.delete_item(owner, item.id)
    assert MatomeApi.Repo.get(MatomeApi.Content.FileBlob, file_blob_id) == nil
  end

  test "video file items stay item_type=file and do not enqueue AI dispatch" do
    owner = user_fixture()
    assert {:ok, matome} = Content.create_matome(owner, %{title: "Screen share"})

    assert {:ok, item} =
             Content.create_file_item(owner, matome.id, %{
               position: 1,
               byte_size: 12_345,
               media_type: "video",
               duration: 42
             })

    assert item.item_type == :file
    assert item.text_content_id == nil
    assert item.file_blob.media_type == "video"
    assert Repo.aggregate(Oban.Job, :count, :id) == 0
  end

  test "item metadata is render hints only and rejects payload identity keys" do
    owner = user_fixture()
    assert {:ok, matome} = Content.create_matome(owner, %{title: "Metadata"})

    assert {:ok, item} =
             Content.create_text_item(owner, matome.id, %{
               position: 1,
               body: "Visible body",
               metadata: %{"display" => "note-card", "collapsed" => true}
             })

    assert item.metadata == %{"display" => "note-card", "collapsed" => true}

    for forbidden <- [
          "storage_key",
          "storageKey",
          "contact_id",
          "contactIds",
          "media_type",
          "byte_size",
          "transcript",
          "summary",
          "body",
          "title",
          "notes",
          "status",
          "workspace_id",
          "processing_state",
          "upload_state"
        ] do
      assert {:error, changeset} =
               Content.create_text_item(owner, matome.id, %{
                 position: System.unique_integer([:positive]),
                 body: "Bad metadata",
                 metadata: %{forbidden => "not allowed"}
               })

      assert %{metadata: [_ | _]} = errors_on(changeset)
    end
  end

  test "workspaces CRUD is scoped by owner" do
    owner = user_fixture()
    other_owner = user_fixture()

    assert {:ok, workspace} = Content.create_workspace(owner, %{name: "Research"})
    assert Content.get_workspace(owner, workspace.id).id == workspace.id
    assert Content.get_workspace(other_owner, workspace.id) == nil
    assert Content.list_workspaces(other_owner, %{"q" => "Research"}) == []

    assert {:ok, updated} = Content.update_workspace(owner, workspace.id, %{description: "Notes"})
    assert updated.description == "Notes"
    assert Content.update_workspace(other_owner, workspace.id, %{name: "Stolen"}) == nil
  end

  test "matomes CRUD is scoped by owner" do
    owner = user_fixture()
    other_owner = user_fixture()

    assert {:ok, matome} = Content.create_matome(owner, %{title: "Kickoff"})
    assert matome.owner_id == owner.id
    assert Content.get_matome(owner, matome.id).id == matome.id
    assert Content.get_matome(other_owner, matome.id) == nil
    assert Content.list_matomes(other_owner) == []

    assert {:ok, updated} = Content.update_matome(owner, matome.id, %{description: "Notes"})
    assert updated.description == "Notes"
    assert Content.update_matome(other_owner, matome.id, %{title: "Stolen"}) == nil
    assert Content.delete_matome(other_owner, matome.id) == nil
    assert {:ok, _} = Content.delete_matome(owner, matome.id)
  end

  test "matomes reject workspaces owned by another user" do
    owner = user_fixture()
    other_owner = user_fixture()
    assert {:ok, other_workspace} = Content.create_workspace(other_owner, %{name: "Other"})

    assert {:error, changeset} =
             Content.create_matome(owner, %{title: "Draft", workspace_id: other_workspace.id})

    assert %{workspace_id: ["is invalid"]} = errors_on(changeset)
  end

  test "items reject matomes owned by another user" do
    owner = user_fixture()
    other_owner = user_fixture()
    assert {:ok, other_matome} = Content.create_matome(other_owner, %{title: "Other"})

    assert Content.create_text_item(owner, other_matome.id, %{position: 1, body: "Draft"}) == nil
  end

  test "contacts CRUD is scoped by owner" do
    owner = user_fixture()
    other_owner = user_fixture()

    assert {:ok, contact} = Content.create_contact(owner, %{display_name: "Alice"})
    assert contact.metadata == %{}
    assert Content.get_contact(owner, contact.id).id == contact.id
    assert Content.get_contact(other_owner, contact.id) == nil
    assert Content.list_contacts(other_owner, %{"q" => "Alice"}) == []

    assert {:ok, updated} =
             Content.update_contact(owner, contact.id, %{metadata: %{"company" => "Acme"}})

    assert updated.metadata == %{"company" => "Acme"}
    assert Content.update_contact(other_owner, contact.id, %{display_name: "Bob"}) == nil
    assert Content.delete_contact(other_owner, contact.id) == nil
    assert {:ok, _} = Content.delete_contact(owner, contact.id)
  end

  test "structured contact fields persist, normalize, and round-trip owner scoped" do
    owner = user_fixture()
    other_owner = user_fixture()

    assert {:ok, contact} =
             Content.create_contact(owner, %{
               display_name: "Alice",
               email: "  Alice@Example.COM ",
               phone: "+1 (555) 123-4567",
               company: "Acme",
               title: "CEO"
             })

    # email lowercased+trimmed, phone separators stripped
    assert contact.email == "alice@example.com"
    assert contact.phone == "+15551234567"
    assert contact.company == "Acme"
    assert contact.title == "CEO"

    # round-trips through a fresh read
    reloaded = Content.get_contact(owner, contact.id)
    assert reloaded.email == "alice@example.com"
    assert reloaded.phone == "+15551234567"
    assert reloaded.company == "Acme"
    assert reloaded.title == "CEO"

    # owner B cannot read owner A's contact fields
    assert Content.get_contact(other_owner, contact.id) == nil

    # owner B cannot write owner A's contact fields
    assert Content.update_contact(other_owner, contact.id, %{email: "evil@example.com"}) == nil
    assert Content.get_contact(owner, contact.id).email == "alice@example.com"
  end

  test "structured contact validation rejects malformed email and phone" do
    owner = user_fixture()

    assert {:error, changeset} =
             Content.create_contact(owner, %{display_name: "Bad", email: "not-an-email"})

    assert %{email: ["is not a valid email"]} = errors_on(changeset)

    assert {:error, changeset} =
             Content.create_contact(owner, %{display_name: "Bad", phone: "abc-123"})

    assert %{phone: ["is not a valid phone number"]} = errors_on(changeset)

    # length bounds (Olivier HARD AC): over-long company/title rejected
    long = String.duplicate("x", 300)

    assert {:error, changeset} =
             Content.create_contact(owner, %{display_name: "Bad", company: long})

    assert %{company: [_ | _]} = errors_on(changeset)

    assert {:error, changeset} =
             Content.create_contact(owner, %{display_name: "Bad", title: long})

    assert %{title: [_ | _]} = errors_on(changeset)
  end

  test "attach and detach contacts on a matome are owner scoped" do
    owner = user_fixture()
    other_owner = user_fixture()

    assert {:ok, matome} = Content.create_matome(owner, %{title: "Standup"})
    assert {:ok, contact} = Content.create_contact(owner, %{display_name: "Alice"})
    assert {:ok, other_contact} = Content.create_contact(other_owner, %{display_name: "Mallory"})

    assert {:ok, join} =
             Content.attach_contact(owner, matome.id, contact.id, %{"role" => "speaker"})

    assert join.role == "speaker"

    reloaded = Content.get_matome(owner, matome.id)
    assert [%{contact_id: cid, role: "speaker"}] = Enum.map(reloaded.matome_contacts, & &1)
    assert cid == contact.id

    # idempotent upsert updates role
    assert {:ok, _} =
             Content.attach_contact(owner, matome.id, contact.id, %{"role" => "attendee"})

    reloaded = Content.get_matome(owner, matome.id)
    assert length(reloaded.matome_contacts) == 1

    # cannot attach another owner's contact
    assert Content.attach_contact(owner, matome.id, other_contact.id) == nil
    # cannot attach to another owner's matome
    assert Content.attach_contact(other_owner, matome.id, contact.id) == nil

    assert {:ok, _} = Content.detach_contact(owner, matome.id, contact.id)
    assert Content.get_matome(owner, matome.id).matome_contacts == []
  end

  test "create_file_item maps client content_length onto byte_size" do
    owner = user_fixture()
    assert {:ok, matome} = Content.create_matome(owner, %{title: "Upload"})

    assert {:ok, item} =
             Content.create_file_item(owner, matome.id, %{
               "item_type" => "file",
               "media_type" => "audio",
               "content_length" => 4096
             })

    assert item.file_blob.byte_size == 4096
    assert MatomeApi.Repo.get(MatomeApi.Content.FileBlob, item.file_blob_id).byte_size == 4096
  end

  test "create_file_item rejects byte_size over the upload ceiling without orphaning rows" do
    owner = user_fixture()
    assert {:ok, matome} = Content.create_matome(owner, %{title: "Big"})
    oversize = MatomeApi.Storage.Presigner.max_upload_bytes() + 1

    assert {:error, changeset} =
             Content.create_file_item(owner, matome.id, %{
               media_type: "audio",
               byte_size: oversize
             })

    assert %{byte_size: [_ | _]} = errors_on(changeset)
    assert MatomeApi.Repo.aggregate(MatomeApi.Content.FileBlob, :count, :id) == 0
    assert MatomeApi.Repo.aggregate(MatomeApi.Content.Item, :count, :id) == 0
  end

  test "moving an item into a matome recomputes position and avoids collision" do
    owner = user_fixture()
    assert {:ok, source} = Content.create_matome(owner, %{title: "Source"})
    assert {:ok, target} = Content.create_matome(owner, %{title: "Target"})

    assert {:ok, moving} =
             Content.create_text_item(owner, source.id, %{body: "Move me"})

    # Target already holds an item at position 0 — the naive move would keep
    # position 0 and collide with items_matome_id_position_index.
    assert {:ok, sitting} =
             Content.create_text_item(owner, target.id, %{body: "Already here"})

    assert sitting.position == 0

    assert {:ok, moved} = Content.update_item(owner, moving.id, %{matome_id: target.id})

    assert moved.matome_id == target.id
    assert moved.position == 1
    assert Content.list_items(owner, target.id) |> Enum.map(& &1.id) == [sitting.id, moved.id]
  end

  defp user_fixture do
    email = "user-#{System.unique_integer([:positive])}@example.com"
    assert {:ok, %{user: user}} = Auth.register_user(%{email: email, password: @password})
    user
  end
end
