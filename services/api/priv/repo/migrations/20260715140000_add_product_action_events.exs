defmodule MatomeApi.Repo.Migrations.AddProductActionEvents do
  use Ecto.Migration

  def up do
    execute """
    INSERT INTO event_catalog
      (key, event_class, enabled, description, retention_days, locked, detail_keys,
       inserted_at, updated_at)
    VALUES
      ('product.matome_added.v1', 'product', false,
       'An opted-in cloud Matome add action.', 30, false, ARRAY[]::varchar[], now(), now()),
      ('product.matome_removed.v1', 'product', false,
       'An opted-in cloud Matome remove action.', 30, false, ARRAY[]::varchar[], now(), now()),
      ('product.matome_archived.v1', 'product', false,
       'An opted-in cloud Matome archive action.', 30, false, ARRAY[]::varchar[], now(), now())
    """
  end

  # Catalog identities are intentionally append-only.
  def down, do: raise("product action event keys are irreversible")
end
