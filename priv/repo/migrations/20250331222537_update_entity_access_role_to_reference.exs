defmodule Xiam.Repo.Migrations.UpdateEntityAccessRoleToReference do
  use Ecto.Migration

  def change do
    alter table(:entity_access) do
      remove :role
      add :role_id, references(:roles, on_delete: :restrict)
    end

    create index(:entity_access, [:role_id])
  end
end
