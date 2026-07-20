defmodule MatomeApi.Content.SpaceLifecycleJobTest do
  use MatomeApi.DataCase, async: true

  alias MatomeApi.Auth
  alias MatomeApi.Content
  alias MatomeApi.Content.{SpaceLifecycleJob, Workspace}
  alias MatomeApi.Repo

  defp user_fixture do
    email = "life-#{System.unique_integer([:positive])}@example.com"
    {:ok, %{user: user}} = Auth.register_user(%{"email" => email, "password" => "correct horse"})
    user
  end

  test "transitions active → suspended → archived → deleted" do
    owner = user_fixture()
    {:ok, workspace} = Content.create_workspace(owner, %{name: "Lifecycle"})

    assert :ok = SpaceLifecycleJob.transition(workspace.id, "suspended")
    assert Repo.get!(Workspace, workspace.id).status == "suspended"

    assert :ok = SpaceLifecycleJob.transition(workspace.id, "archived")
    assert Repo.get!(Workspace, workspace.id).status == "archived"

    assert :ok = SpaceLifecycleJob.transition(workspace.id, "deleted")
    assert Repo.get!(Workspace, workspace.id).status == "deleted"
  end

  test "discards invalid transitions" do
    owner = user_fixture()
    {:ok, workspace} = Content.create_workspace(owner, %{name: "Bad"})

    assert {:discard, {:invalid_transition, "active", "deleted"}} =
             SpaceLifecycleJob.transition(workspace.id, "deleted")
  end

  test "expire_due enqueues suspend for past expires_at" do
    owner = user_fixture()
    {:ok, workspace} = Content.create_workspace(owner, %{name: "Expiring"})

    past = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

    workspace
    |> Workspace.admin_changeset(%{expires_at: past})
    |> Repo.update!()

    assert [{:ok, %Oban.Job{args: args}}] = SpaceLifecycleJob.expire_due()
    workspace_id = args["workspace_id"] || args[:workspace_id]
    to_status = args["to_status"] || args[:to_status]
    assert workspace_id == workspace.id
    assert to_status == "suspended"
  end
end
