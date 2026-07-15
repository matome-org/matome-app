defmodule MatomeApi.AdminPrivilegedActionsTest do
  use MatomeApi.DataCase, async: false

  import Ecto.Query

  alias MatomeApi.Admin
  alias MatomeApi.Auth
  alias MatomeApi.Auth.RefreshToken
  alias MatomeApi.Content
  alias MatomeApi.Content.{SpaceMember, Workspace}
  alias MatomeApi.Events.{Event, EventCatalog}

  @admin "admin@example.com"
  @ip "198.51.100.24"

  defp register!(email) do
    {:ok, auth} =
      Auth.register_user(%{
        "email" => email,
        "password" => "correct horse battery staple"
      })

    auth
  end

  defp mutation_opts(overrides \\ []) do
    Keyword.merge(
      [
        actor: %{email: @admin},
        otp_verified_at: System.os_time(:second),
        remote_ip: @ip
      ],
      overrides
    )
  end

  defp read_opts(resource) do
    [actor: %{email: @admin}, remote_ip: @ip, audit_resource: resource]
  end

  defp event!(prefix) do
    Repo.one!(
      from e in Event,
        where: like(e.event_key, ^"#{prefix}%"),
        order_by: [desc: e.id],
        limit: 1
    )
  end

  defp assert_control(event, target_type, target_id, before, after_state) do
    assert event.actor_id == nil
    assert event.actor_email == @admin
    assert event.remote_ip == @ip
    assert event.subject_type == target_type
    assert event.subject_id == to_string(target_id)
    assert event.details["before"] == before
    assert event.details["after"] == after_state
  end

  describe "session mutations" do
    test "revocation records the complete control event" do
      %{user: user, refresh_token: raw_token} = register!("session-target@example.com")
      token = Repo.get_by!(RefreshToken, token: raw_token)

      assert :ok = Admin.revoke_session(%{email: @admin}, token.jti, mutation_opts())

      assert %RefreshToken{revoked_at: %DateTime{}} = Repo.get!(RefreshToken, token.id)

      event = event!("security.admin.session_revoked.")
      assert event.owner_id == user.id
      assert_control(event, "session", token.jti, "active", "revoked")
    end

    test "a non-allowlisted identity cannot revoke" do
      %{refresh_token: raw_token} = register!("allowlist-safe@example.com")
      token = Repo.get_by!(RefreshToken, token: raw_token)

      assert {:error, :forbidden} =
               Admin.revoke_session(
                 %{email: "stranger@example.com"},
                 token.jti,
                 mutation_opts(actor: %{email: "stranger@example.com"})
               )

      assert is_nil(Repo.get!(RefreshToken, token.id).revoked_at)
    end
  end

  describe "space mutations" do
    setup do
      %{user: owner} = register!("space-owner@example.com")
      %{user: member_user} = register!("space-member@example.com")
      {:ok, workspace} = Content.create_workspace(owner, %{name: "Controlled Space"})

      %{owner: owner, member_user: member_user, workspace: workspace}
    end

    test "policy update records target, before/after, actor, and IP", %{workspace: workspace} do
      assert {:ok, %Workspace{quota_bytes: 4096}} =
               Admin.update_space(workspace.id, %{quota_bytes: 4096}, mutation_opts())

      event = event!("security.admin.space_updated.")
      before = event.details["before"] |> Jason.decode!()
      after_state = event.details["after"] |> Jason.decode!()

      assert before["quota_bytes"] == nil
      assert after_state["quota_bytes"] == 4096

      assert_control(
        event,
        "workspace",
        workspace.id,
        event.details["before"],
        event.details["after"]
      )

      event_json = Jason.encode!(event.details)
      refute event_json =~ workspace.name
      refute event_json =~ "space-owner@example.com"
    end

    test "member add records the created membership as target", %{
      workspace: workspace,
      member_user: user
    } do
      assert {:ok, member} =
               Admin.add_space_member(workspace.id, user.id, "viewer", mutation_opts())

      event = event!("security.admin.space_member_added.")
      assert event.details["workspace_id"] == workspace.id
      assert event.details["user_id"] == user.id
      assert_control(event, "space_member", member.id, "absent", "viewer")
    end

    test "member revoke records the membership transition", %{
      workspace: workspace,
      member_user: user
    } do
      member =
        %SpaceMember{}
        |> SpaceMember.changeset(%{
          workspace_id: workspace.id,
          user_id: user.id,
          role: "member",
          granted_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })
        |> Repo.insert!()

      assert {:ok, %SpaceMember{revoked_at: %DateTime{}}} =
               Admin.revoke_space_member(member.id, mutation_opts())

      event = event!("security.admin.space_member_revoked.")
      assert_control(event, "space_member", member.id, "member", "revoked")
    end

    test "lifecycle transition records old and new status", %{workspace: workspace} do
      assert {:ok, %Workspace{status: "suspended"}} =
               Admin.transition_space(workspace.id, "suspended", mutation_opts())

      event = event!("security.admin.space_lifecycle.")
      assert_control(event, "workspace", workspace.id, "active", "suspended")
    end

    test "stale OTP cannot update a space", %{workspace: workspace} do
      stale = System.os_time(:second) - 3600

      assert {:error, :recent_otp_required} =
               Admin.update_space(
                 workspace.id,
                 %{quota_bytes: 1},
                 mutation_opts(otp_verified_at: stale)
               )

      assert is_nil(Repo.get!(Workspace, workspace.id).quota_bytes)
    end

    test "mandatory event failure rolls back its mutation", %{workspace: workspace} do
      invalid_ip = String.duplicate("1", 65)

      assert {:error, {:audit_failed, _changeset}} =
               Admin.update_space(
                 workspace.id,
                 %{quota_bytes: 1},
                 mutation_opts(remote_ip: invalid_ip)
               )

      assert is_nil(Repo.get!(Workspace, workspace.id).quota_bytes)

      refute Repo.exists?(
               from e in Event, where: like(e.event_key, "security.admin.space_updated.%")
             )
    end
  end

  describe "sensitive reads" do
    test "cross-user session metadata emits a mandatory event" do
      register!("metadata-subject@example.com")

      assert [_entry] = Admin.session_tree(read_opts("sessions"))

      event = event!("security.admin.sensitive_read.")
      assert event.actor_email == @admin
      assert event.remote_ip == @ip
      assert event.subject_type == "admin_view"
      assert event.subject_id == "sessions"
      assert event.details == %{"resource" => "sessions", "result" => "success"}
    end

    test "every cross-user admin view emits its policy-required read event" do
      %{user: owner} = register!("read-owner@example.com")
      {:ok, workspace} = Content.create_workspace(owner, %{name: "Read Audit"})

      Admin.dashboard_stats(read_opts("dashboard"))
      Admin.list_users(read_opts("users"))
      Admin.list_spaces(read_opts("spaces"))
      Admin.get_space(workspace.id, read_opts("space"))
      Admin.list_audit_events(read_opts("audit"))

      resources =
        from(e in Event,
          where: e.event_key == "security.admin.sensitive_read.v1",
          select: fragment("?->>'resource'", e.details)
        )
        |> Repo.all()
        |> MapSet.new()

      assert MapSet.subset?(MapSet.new(~w(dashboard users spaces space audit)), resources)
    end
  end

  describe "configuration mutation seam" do
    test "catalog policy change requires recent OTP and records the full control event" do
      key = "operational.upload_completed.v1"
      before = Repo.get!(EventCatalog, key)

      assert {:ok, %EventCatalog{retention_days: 120}} =
               Admin.update_event_catalog(key, %{retention_days: 120}, mutation_opts())

      event = event!("security.event_catalog.changed.v2")
      before_state = Jason.decode!(event.details["before"])
      after_state = Jason.decode!(event.details["after"])

      assert before_state["retention_days"] == before.retention_days
      assert after_state["retention_days"] == 120
      assert event.details["changed_fields"] == ["retention_days"]
      assert_control(event, "event_catalog", key, event.details["before"], event.details["after"])
    end

    test "stale OTP cannot change collection policy" do
      key = "operational.upload_completed.v1"
      before = Repo.get!(EventCatalog, key)

      assert {:error, :recent_otp_required} =
               Admin.update_event_catalog(
                 key,
                 %{retention_days: 120},
                 mutation_opts(otp_verified_at: System.os_time(:second) - 3600)
               )

      assert Repo.get!(EventCatalog, key).retention_days == before.retention_days
    end
  end
end
