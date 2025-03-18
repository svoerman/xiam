defmodule XIAM.Repo.Migrations.AddMfaSettingsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # MFA settings
      add :mfa_enabled, :boolean, default: false, null: false
      add :mfa_secret, :binary
      add :mfa_backup_codes, {:array, :string}
    end

    create index(:users, [:mfa_enabled])
  end
end
