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

  defp user_fixture do
    email = "user-#{System.unique_integer([:positive])}@example.com"
    assert {:ok, %{user: user}} = Auth.register_user(%{email: email, password: @password})
    user
  end
end
