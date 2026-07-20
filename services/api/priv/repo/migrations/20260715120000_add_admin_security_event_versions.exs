defmodule MatomeApi.Repo.Migrations.AddAdminSecurityEventVersions do
  use Ecto.Migration

  def up do
    execute """
    INSERT INTO event_catalog
      (key, event_class, enabled, description, retention_days, locked, detail_keys,
       inserted_at, updated_at)
    VALUES
      ('security.event_catalog.changed.v2', 'security', true,
       'An administrator changed collection policy with before and after state.',
       365, true, ARRAY['changed_fields', 'before', 'after', 'result'], now(), now()),
      ('security.admin.session_revoked.v2', 'security', true,
       'An administrator revoked a user session with before and after state.',
       365, true, ARRAY['before', 'after'], now(), now()),
      ('security.admin.space_updated.v2', 'security', true,
       'An administrator changed Space policy with before and after state.',
       365, true, ARRAY['changed_keys', 'before', 'after'], now(), now()),
      ('security.admin.space_member_added.v2', 'security', true,
       'An administrator added a Space member with before and after state.',
       365, true, ARRAY['workspace_id', 'user_id', 'role', 'before', 'after'], now(), now()),
      ('security.admin.space_member_revoked.v2', 'security', true,
       'An administrator revoked a Space member with before and after state.',
       365, true, ARRAY['workspace_id', 'user_id', 'before', 'after'], now(), now()),
      ('security.admin.space_lifecycle.v2', 'security', true,
       'An administrator changed Space lifecycle with before and after state.',
       365, true, ARRAY['before', 'after'], now(), now()),
      ('security.admin.sensitive_read.v1', 'security', true,
       'An administrator read sensitive cross-user metadata.',
       365, true, ARRAY['resource', 'result'], now(), now())
    """
  end

  # Security catalog identities are intentionally append-only.
  def down, do: raise("admin security event versions are irreversible")
end
