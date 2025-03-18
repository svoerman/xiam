defmodule XIAM.Repo.Migrations.CreateSystemHealthChecks do
  use Ecto.Migration

  def change do
    create table(:system_health_checks) do
      add :timestamp, :utc_datetime, null: false
      add :database_status, :string, null: false
      add :application_status, :string, null: false
      add :memory_total, :bigint
      add :disk_available, :string
      add :disk_used_percent, :string
      add :node_count, :integer
      add :process_count, :integer
    end

    # Only keep one record per hour to avoid excessive data
    create unique_index(:system_health_checks, [:timestamp])
  end
end
