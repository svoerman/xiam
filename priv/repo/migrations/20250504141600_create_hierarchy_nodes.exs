defmodule XIAM.Repo.Migrations.CreateHierarchyNodes do
  use Ecto.Migration

  def change do
    create table(:hierarchy_nodes) do
      add :path, :string, null: false  # will store ltree
      add :parent_id, references(:hierarchy_nodes, on_delete: :restrict), null: true
      add :node_type, :string, null: false  # User-defined type (e.g., "country", "company", "installation")
      add :name, :string, null: false
      add :metadata, :map
      
      timestamps()
    end

    # Create regular indexes first
    create index(:hierarchy_nodes, [:parent_id])
    create unique_index(:hierarchy_nodes, [:path])
    
    # Then create ltree-specific indexes using a more compatible syntax
    # First create a function to convert text to ltree safely
    execute("""
    CREATE OR REPLACE FUNCTION text2ltree(text) RETURNS ltree AS $$
    BEGIN
      RETURN $1::ltree;
    EXCEPTION
      WHEN OTHERS THEN RETURN ''::ltree;
    END;
    $$ LANGUAGE plpgsql IMMUTABLE;
    """)
    
    # GiST index is the most appropriate for ltree path operations
    execute("CREATE INDEX hierarchy_nodes_path_gist ON hierarchy_nodes USING GIST (text2ltree(path))")
    
    # Trigram index for text search on paths
    execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")
    execute("CREATE INDEX hierarchy_nodes_path_trgm ON hierarchy_nodes USING GIN (path gin_trgm_ops)")
    
    # Standard btree index for equality comparisons
    execute("CREATE INDEX hierarchy_nodes_path_btree ON hierarchy_nodes USING BTREE (path)")
  end
end
