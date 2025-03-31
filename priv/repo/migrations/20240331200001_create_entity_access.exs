defmodule Xiam.Repo.Migrations.CreateEntityAccess do
  use Ecto.Migration

  def change do
    create table(:entity_access) do
      add :user_id, :integer, null: false
      add :entity_type, :string, null: false
      add :entity_id, :integer, null: false
      add :role, :string, null: false

      timestamps()
    end

    create index(:entity_access, [:user_id])
    create index(:entity_access, [:entity_type, :entity_id])
    create unique_index(:entity_access, [:user_id, :entity_type, :entity_id])
  end
end
