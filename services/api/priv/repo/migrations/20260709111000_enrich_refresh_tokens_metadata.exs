defmodule MatomeApi.Repo.Migrations.EnrichRefreshTokensMetadata do
  use Ecto.Migration

  # W4 p2-core-backoffice (#1872): session metadata for the sessions view
  # (W6) and revocation (W5). Expand phase of expand→contract: every column
  # is additive and nullable so rows minted by the previous code shape stay
  # valid; NOT NULL tightening (if ever) is a later contract migration.
  #
  # - `jti`/`family_id`/`rotated_from` — rotation chain. Every login starts a
  #   new family; every refresh keeps the family and records the previous
  #   token's jti, so a session's history is one family_id and revoking a
  #   session (W5) is one family-wide predicate.
  # - `revoked_at` — soft-revocation seam for W5; rotated tokens are retained
  #   with this set (instead of deleted) so presenting an already-rotated
  #   token is distinguishable from garbage.
  # - `ip`/`user_agent`/`device_id`/`login_method`/`last_seen_at` — capture
  #   metadata; retention bounds documented in
  #   docs/session-metadata-retention.md.
  def up do
    alter table(:refresh_tokens) do
      add :device_id, references(:devices, on_delete: :nilify_all)
      add :ip, :string, size: 45
      add :user_agent, :text
      add :login_method, :string
      add :last_seen_at, :utc_datetime
      add :revoked_at, :utc_datetime
      add :jti, :string
      add :family_id, :uuid
      add :rotated_from, :string
    end

    create index(:refresh_tokens, [:device_id])
    create index(:refresh_tokens, [:family_id])

    # Backfill for rows minted before this migration: their last activity is
    # best approximated by insertion, and each becomes its own single-token
    # family (they predate rotation tracking, so no chain exists to recover).
    # `jti` is intentionally left NULL — it lives inside the JWT and cannot
    # be reconstructed from the stored columns.
    execute "UPDATE refresh_tokens SET last_seen_at = inserted_at WHERE last_seen_at IS NULL"
    execute "UPDATE refresh_tokens SET family_id = gen_random_uuid() WHERE family_id IS NULL"
  end

  def down do
    alter table(:refresh_tokens) do
      remove :rotated_from
      remove :family_id
      remove :jti
      remove :revoked_at
      remove :last_seen_at
      remove :login_method
      remove :user_agent
      remove :ip
      remove :device_id
    end
  end
end
