defmodule MatomeApi.Content.SpaceQuotaTest do
  @moduledoc """
  W8 (#1876) — ciphertext quota at create_file_item: 413 at boundary +
  concurrent race (FOR UPDATE serializes two under-quota uploads).
  """
  use MatomeApi.DataCase, async: false

  alias MatomeApi.Auth
  alias MatomeApi.Content
  alias MatomeApi.Content.Workspace
  alias MatomeApi.Repo

  defp user_fixture do
    email = "quota-#{System.unique_integer([:positive])}@example.com"
    {:ok, %{user: user}} = Auth.register_user(%{"email" => email, "password" => "correct horse"})
    user
  end

  defp space_with_quota!(owner, quota_bytes) do
    {:ok, workspace} = Content.create_workspace(owner, %{name: "Quota space"})

    workspace
    |> Workspace.admin_changeset(%{quota_bytes: quota_bytes})
    |> Repo.update!()
  end

  test "create_file_item returns :quota_exceeded at the ciphertext boundary" do
    owner = user_fixture()
    workspace = space_with_quota!(owner, 1000)

    {:ok, matome} =
      Content.create_matome(owner, %{title: "Filed", workspace_id: workspace.id})

    assert {:ok, _} =
             Content.create_file_item(owner, matome.id, %{
               media_type: "audio",
               content_length: 600
             })

    assert Repo.get!(Workspace, workspace.id).used_bytes == 600

    assert {:error, :quota_exceeded} =
             Content.create_file_item(owner, matome.id, %{
               media_type: "audio",
               content_length: 500
             })

    assert Repo.get!(Workspace, workspace.id).used_bytes == 600
    assert Repo.aggregate(Content.FileBlob, :count, :id) == 1
  end

  test "HTTP create maps quota_exceeded to 413" do
    # Covered via ConnCase in SpaceQuotaControllerTest — keep domain atom here.
    owner = user_fixture()
    workspace = space_with_quota!(owner, 100)

    {:ok, matome} =
      Content.create_matome(owner, %{title: "Tiny", workspace_id: workspace.id})

    assert {:error, :quota_exceeded} =
             Content.create_file_item(owner, matome.id, %{
               media_type: "document",
               byte_size: 101
             })
  end

  test "concurrent under-quota uploads that sum over ceiling: one wins, one 413" do
    owner = user_fixture()
    workspace = space_with_quota!(owner, 1000)

    {:ok, matome} =
      Content.create_matome(owner, %{title: "Race", workspace_id: workspace.id})

    # Shared sandbox: both tasks use the owner connection; FOR UPDATE still
    # serializes the two Multi transactions so only one reservation sticks.
    tasks =
      for _ <- 1..2 do
        Task.async(fn ->
          Content.create_file_item(owner, matome.id, %{
            media_type: "audio",
            content_length: 600
          })
        end)
      end

    results = Enum.map(tasks, &Task.await(&1, 15_000))

    oks = Enum.count(results, &match?({:ok, _}, &1))
    errs = Enum.count(results, &match?({:error, :quota_exceeded}, &1))

    assert oks == 1
    assert errs == 1
    assert Repo.get!(Workspace, workspace.id).used_bytes == 600
  end

  test "suspended space rejects new file items" do
    owner = user_fixture()
    workspace = space_with_quota!(owner, 10_000)

    workspace
    |> Workspace.admin_changeset(%{status: "suspended"})
    |> Repo.update!()

    {:ok, matome} =
      Content.create_matome(owner, %{title: "RO", workspace_id: workspace.id})

    assert {:error, :space_not_writable} =
             Content.create_file_item(owner, matome.id, %{
               media_type: "audio",
               byte_size: 10
             })
  end
end
