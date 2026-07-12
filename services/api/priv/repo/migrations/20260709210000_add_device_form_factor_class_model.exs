defmodule MatomeApi.Repo.Migrations.AddDeviceFormFactorClassModel do
  use Ecto.Migration

  def change do
    alter table(:devices) do
      add :form_factor, :string
      add :device_class, :string
      add :model, :string
    end
  end
end
