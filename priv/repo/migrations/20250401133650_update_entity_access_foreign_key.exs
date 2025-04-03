defmodule XIAM.Repo.Migrations.UpdateEntityAccessForeignKey do
  use Ecto.Migration

  def change do
    # Drop the existing foreign key constraint with ON DELETE RESTRICT
    drop constraint(:entity_access, "entity_access_role_id_fkey")
    
    # Add a new foreign key constraint with ON DELETE DELETE_ALL
    alter table(:entity_access) do
      modify :role_id, references(:roles, on_delete: :delete_all)
    end
  end
end
