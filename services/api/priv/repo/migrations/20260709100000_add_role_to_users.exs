defmodule MatomeApi.Repo.Migrations.AddRoleToUsers do
  use Ecto.Migration

  @moduledoc """
  W3 #1871 (plan p2-core-backoffice §9.1) — identity axis of the /admin gate.

  Additive only: every existing row defaults to 'user'. There is NO signup
  path to any privileged role — admins are provisioned out-of-band (SQL /
  release task), which is what keeps this a hard allowlist.
  """

  def change do
    alter table(:users) do
      add :role, :string, null: false, default: "user"
    end

    create constraint(:users, :users_role_must_be_known,
             check: "role IN ('user', 'admin', 'superadmin')"
           )
  end
end
