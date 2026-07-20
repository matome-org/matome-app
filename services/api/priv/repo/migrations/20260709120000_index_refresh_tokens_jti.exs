defmodule MatomeApi.Repo.Migrations.IndexRefreshTokensJti do
  use Ecto.Migration

  # W5 p2-core-backoffice (#1873): the per-request revocation check resolves
  # an access token's `sid` claim to its refresh_tokens row by `jti` on every
  # authenticated request (cold-cache path), so the lookup must be indexed.
  # Plain (non-unique) index: `jti` is nullable (pre-W4 rows were backfilled
  # with NULL) and values are Guardian-generated UUIDs.
  def change do
    create index(:refresh_tokens, [:jti])
  end
end
