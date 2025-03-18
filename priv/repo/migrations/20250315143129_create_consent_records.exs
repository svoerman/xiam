defmodule XIAM.Repo.Migrations.CreateConsentRecords do
  use Ecto.Migration

  def change do
    create table(:consent_records) do
      add :consent_type, :string, null: false
      add :consent_given, :boolean, default: false, null: false
      add :ip_address, :string
      add :user_agent, :string
      add :revoked_at, :utc_datetime
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:consent_records, [:user_id])
    create index(:consent_records, [:consent_type])
    create index(:consent_records, [:consent_given])
    create index(:consent_records, [:revoked_at])
  end
end
