defmodule MatomeApi.Repo.Migrations.AddWorkspaceTwoAxisQuotaLifecycleMembers do
  @moduledoc """
  W8 + #102 Core reconcile — see docs/spaces-two-axis-reconcile.md.

  Additive only: two-axis columns, quota/lifecycle, space_members.
  Physical table remains `workspaces`.
  """
  use Ecto.Migration

  def change do
    alter table(:workspaces) do
      # Axis A — sync mode. Core default false: only cloud spaces live here.
      add :is_local, :boolean, null: false, default: false
      # Axis B — tenancy.
      add :space_type, :string, null: false, default: "personal"

      add :quota_bytes, :bigint
      add :used_bytes, :bigint, null: false, default: 0
      add :expires_at, :utc_datetime
      add :status, :string, null: false, default: "active"
    end

    create constraint(:workspaces, :workspaces_space_type_check,
             check: "space_type IN ('personal', 'shared', 'org')"
           )

    create constraint(:workspaces, :workspaces_status_check,
             check: "status IN ('active', 'suspended', 'archived', 'deleted')"
           )

    create constraint(:workspaces, :workspaces_used_bytes_nonneg, check: "used_bytes >= 0")

    create constraint(:workspaces, :workspaces_quota_bytes_positive,
             check: "quota_bytes IS NULL OR quota_bytes >= 0"
           )

    # local ⟹ personal; org ⟹ cloud
    create constraint(:workspaces, :workspaces_local_implies_personal,
             check: "(is_local = false) OR (space_type = 'personal')"
           )

    create constraint(:workspaces, :workspaces_org_implies_cloud,
             check: "(space_type <> 'org') OR (is_local = false)"
           )

    create index(:workspaces, [:status])
    create index(:workspaces, [:expires_at])

    create table(:space_members) do
      add :workspace_id, references(:workspaces, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :role, :string, null: false, default: "member"
      add :granted_at, :utc_datetime, null: false
      add :revoked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:space_members, [:workspace_id])
    create index(:space_members, [:user_id])
    create unique_index(:space_members, [:workspace_id, :user_id])

    create constraint(:space_members, :space_members_role_check,
             check: "role IN ('owner', 'admin', 'member', 'viewer')"
           )
  end
end
