defmodule XIAM.Repo.Migrations.AddDataRetentionFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :last_sign_in_at, :utc_datetime
      add :anonymized, :boolean, default: false, null: false
      add :admin, :boolean, default: false, null: false
      add :deletion_requested, :boolean, default: false, null: false
      add :name, :string
    end
    
    create index(:users, [:anonymized])
    create index(:users, [:admin])
    create index(:users, [:deletion_requested])
    create index(:users, [:last_sign_in_at])
  end
end
