defmodule XIAM.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  def change do
    create table(:audit_logs) do
      add :action, :string, null: false
      add :actor_id, references(:users, on_delete: :nilify_all)
      add :actor_type, :string, default: "user"
      add :resource_type, :string, null: false
      add :resource_id, :string
      add :metadata, :map, default: %{}
      add :ip_address, :string
      add :user_agent, :string

      timestamps()
    end

    create index(:audit_logs, [:actor_id])
    create index(:audit_logs, [:action])
    create index(:audit_logs, [:resource_type, :resource_id])
    create index(:audit_logs, [:inserted_at])
  end
end
