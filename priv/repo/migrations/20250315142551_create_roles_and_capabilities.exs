defmodule XIAM.Repo.Migrations.CreateRolesAndCapabilities do
  use Ecto.Migration

  def change do
    # Create capabilities table
    create table(:capabilities) do
      add :name, :string, null: false
      add :description, :text

      timestamps()
    end

    create unique_index(:capabilities, [:name])

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
