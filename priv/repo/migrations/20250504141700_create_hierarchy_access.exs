defmodule XIAM.Repo.Migrations.CreateHierarchyAccess do
  use Ecto.Migration

  def change do
    create table(:hierarchy_access) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :access_path, :string, null: false  # will store ltree
      add :role_id, references(:roles, on_delete: :restrict), null: false
      
      timestamps()
    end

    # Create standard indexes first
    create index(:hierarchy_access, [:user_id])
    create unique_index(:hierarchy_access, [:user_id, :access_path])
    
    # Then create the ltree-specific indexes using more compatible syntax
    # GiST index for ltree path operations (containment, ancestry)
    # Uses the text2ltree function created in the previous migration
    execute("CREATE INDEX hierarchy_access_path_gist ON hierarchy_access USING GIST (text2ltree(access_path))")
    
    # Standard btree index for equality comparisons
    execute("CREATE INDEX hierarchy_access_path_btree ON hierarchy_access USING BTREE (access_path)")
  end
end
