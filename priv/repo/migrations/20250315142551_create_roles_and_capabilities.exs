defmodule XIAM.Repo.Migrations.CreateRolesAndCapabilities do
  use Ecto.Migration

  def change do
    # Skip creating capabilities table if it already exists
    # We'll use execute to run SQL that safely checks if table exists
    execute("""    
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'capabilities') THEN
        CREATE TABLE capabilities (
          id BIGSERIAL PRIMARY KEY,
          name VARCHAR(255) NOT NULL,
          description TEXT,
          inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMP NOT NULL DEFAULT NOW()
        );
      END IF;
    END
    $$;
    """)
    
    # Create unique index on name if it doesn't exist
    execute("CREATE INDEX IF NOT EXISTS capabilities_name_index ON capabilities(name);")

    # Create roles table
    create table(:roles) do
      add :name, :string, null: false
      add :description, :text

      timestamps()
    end

    create unique_index(:roles, [:name])

    # Create many-to-many join table for roles and capabilities
    create table(:roles_capabilities, primary_key: false) do
      add :role_id, references(:roles, on_delete: :delete_all), null: false
      add :capability_id, references(:capabilities, on_delete: :delete_all), null: false
    end

    create unique_index(:roles_capabilities, [:role_id, :capability_id])

    # Add role_id to users table
    alter table(:users) do
      add :role_id, references(:roles, on_delete: :nilify_all)
    end

    create index(:users, [:role_id])
  end
end
