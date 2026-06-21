defmodule MatomeApi.ContentTest do
  use MatomeApi.DataCase, async: true

  alias MatomeApi.Auth
  alias MatomeApi.Content

  @password "correct horse battery staple"

  test "recordings default to pending and are scoped by owner" do
    owner = user_fixture()
    other_owner = user_fixture()

    assert {:ok, recording} = Content.create_recording(owner, %{title: "Daily standup"})

    assert recording.status == :pending
    assert recording.owner_id == owner.id
    assert Content.get_recording(owner, recording.id).id == recording.id
    assert Content.get_recording(other_owner, recording.id) == nil
    assert Content.list_recordings(other_owner) == []
  end

  test "recording search only returns owned rows" do
    owner = user_fixture()
    other_owner = user_fixture()

    assert {:ok, owned} =
             Content.create_recording(owner, %{title: "Focus memo", transcript: "alpha beta"})

    assert {:ok, _other} =
             Content.create_recording(other_owner, %{
               title: "Focus memo",
               transcript: "alpha beta"
             })

    assert [recording] = Content.list_recordings(owner, %{"q" => "alpha"})
    assert recording.id == owned.id
  end

  test "recordings accept each allowlisted media_type" do
    owner = user_fixture()

    for type <- ~w(audio meeting image document) do
      assert {:ok, recording} =
               Content.create_recording(owner, %{title: "Typed #{type}", media_type: type})

      assert recording.media_type == type
    end
  end

  test "recordings allow a nil media_type (optional)" do
    owner = user_fixture()
    assert {:ok, recording} = Content.create_recording(owner, %{title: "Untyped"})
    assert recording.media_type == nil
  end

  test "recordings reject a media_type outside the allowlist" do
    owner = user_fixture()

    assert {:error, changeset} =
             Content.create_recording(owner, %{title: "Bad", media_type: "video"})

    assert %{media_type: ["is invalid"]} = errors_on(changeset)

    assert {:error, changeset} =
             Content.create_recording(owner, %{title: "Bad", media_type: "../../etc"})

    assert %{media_type: ["is invalid"]} = errors_on(changeset)
  end

  test "recordings server-derive storage_key inside the owner prefix and ignore client values" do
    owner = user_fixture()

    assert {:ok, recording} =
             Content.create_recording(owner, %{
               title: "Scoped",
               storage_key: "owners/9999/recordings/1/media"
             })

    assert recording.storage_key == "owners/#{owner.id}/recordings/#{recording.id}/media"
  end

  test "recordings reject workspaces owned by another user" do
    owner = user_fixture()
    other_owner = user_fixture()
    assert {:ok, other_workspace} = Content.create_workspace(other_owner, %{name: "Other"})

    assert {:error, changeset} =
             Content.create_recording(owner, %{title: "Draft", workspace_id: other_workspace.id})

    assert %{workspace_id: ["is invalid"]} = errors_on(changeset)
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

  test "recordings reject matomes owned by another user" do
    owner = user_fixture()
    other_owner = user_fixture()
    assert {:ok, other_matome} = Content.create_matome(other_owner, %{title: "Other"})

    assert {:error, changeset} =
             Content.create_recording(owner, %{title: "Draft", matome_id: other_matome.id})

    assert %{matome_id: ["is invalid"]} = errors_on(changeset)
  end

  test "recordings accept matomes owned by the same user" do
    owner = user_fixture()
    assert {:ok, matome} = Content.create_matome(owner, %{title: "Mine"})

    assert {:ok, recording} =
             Content.create_recording(owner, %{title: "Item", matome_id: matome.id})

    assert recording.matome_id == matome.id
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

  defp user_fixture do
    email = "user-#{System.unique_integer([:positive])}@example.com"
    assert {:ok, %{user: user}} = Auth.register_user(%{email: email, password: @password})
    user
  end
end
