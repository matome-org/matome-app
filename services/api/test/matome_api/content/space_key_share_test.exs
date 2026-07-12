defmodule MatomeApi.Content.SpaceKeyShareTest do
  @moduledoc """
  W9 (#1877) / ADR-0003 — membership permission ⟂ crypto wrap access.
  """
  use MatomeApi.DataCase, async: true

  alias MatomeApi.Auth
  alias MatomeApi.Content
  alias MatomeApi.Content.SpaceMember
  alias MatomeApi.Repo

  defp user!(prefix) do
    email = "#{prefix}-#{System.unique_integer([:positive])}@example.com"
    {:ok, %{user: user}} = Auth.register_user(%{"email" => email, "password" => "correct horse"})
    user
  end

  test "create_workspace seeds an owner membership row" do
    owner = user!("owner")
    {:ok, workspace} = Content.create_workspace(owner, %{name: "Shared"})

    assert Content.space_role(owner, workspace.id) == "owner"
    assert Repo.get_by(SpaceMember, workspace_id: workspace.id, user_id: owner.id).role == "owner"
  end

  test "member can list a space they do not own; stranger cannot" do
    owner = user!("own")
    member = user!("mem")
    stranger = user!("str")

    {:ok, workspace} = Content.create_workspace(owner, %{name: "Club"})

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %SpaceMember{}
    |> SpaceMember.changeset(%{
      workspace_id: workspace.id,
      user_id: member.id,
      role: "member",
      granted_at: now
    })
    |> Repo.insert!()

    assert Content.get_workspace(member, workspace.id).id == workspace.id
    assert Content.get_workspace(stranger, workspace.id) == nil
    assert Enum.any?(Content.list_workspaces(member), &(&1.id == workspace.id))
    refute Enum.any?(Content.list_workspaces(stranger), &(&1.id == workspace.id))
  end

  test "put_space_key_wrap requires sharer role + recipient membership; stores opaque blob" do
    owner = user!("own")
    member = user!("mem")
    outsider = user!("out")

    {:ok, workspace} = Content.create_workspace(owner, %{name: "E2E"})
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %SpaceMember{}
    |> SpaceMember.changeset(%{
      workspace_id: workspace.id,
      user_id: member.id,
      role: "member",
      granted_at: now
    })
    |> Repo.insert!()

    # Outsider cannot wrap for member
    assert {:error, :forbidden} =
             Content.put_space_key_wrap(outsider, workspace.id, member.id, %{
               "wrapper_blob" => "dGVzdA==",
               "ephemeral_pubkey" => "cHVi"
             })

    # Owner cannot wrap for non-member
    assert {:error, :not_a_member} =
             Content.put_space_key_wrap(owner, workspace.id, outsider.id, %{
               "wrapper_blob" => "dGVzdA==",
               "ephemeral_pubkey" => "cHVi"
             })

    assert {:ok, wrap} =
             Content.put_space_key_wrap(owner, workspace.id, member.id, %{
               "wrapper_blob" => "d3JhcC1ibG9iLW9wYXF1ZQ==",
               "ephemeral_pubkey" => "ZXBoZW1lcmFs"
             })

    assert wrap.wrapper_blob == "d3JhcC1ibG9iLW9wYXF1ZQ=="
    assert wrap.alg_id == 1
    assert is_nil(wrap.revoked_at)

    # Recipient fetches own wrap; Core never sees plaintext Space-DEK
    assert Content.get_own_space_key_wrap(member, workspace.id).id == wrap.id
    assert Content.get_own_space_key_wrap(owner, workspace.id) == nil

    {:ok, pending} = Content.list_pending_key_shares(owner, workspace.id)
    refute Enum.any?(pending, &(&1.user_id == member.id))
  end

  test "admin panel membership without wrap leaves pending key share" do
    owner = user!("own")
    member = user!("mem")
    {:ok, workspace} = Content.create_workspace(owner, %{name: "Pending"})
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %SpaceMember{}
    |> SpaceMember.changeset(%{
      workspace_id: workspace.id,
      user_id: member.id,
      role: "viewer",
      granted_at: now
    })
    |> Repo.insert!()

    {:ok, pending} = Content.list_pending_key_shares(owner, workspace.id)
    assert Enum.map(pending, & &1.user_id) == [member.id]

    # Permission without wrap: member can see space metadata, has no wrap
    assert Content.get_workspace(member, workspace.id)
    assert Content.get_own_space_key_wrap(member, workspace.id) == nil
  end
end
