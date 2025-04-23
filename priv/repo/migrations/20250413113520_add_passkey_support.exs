defmodule XIAM.Repo.Migrations.AddPasskeySupport do
  use Ecto.Migration

  def change do
    create table(:user_passkeys) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :credential_id, :binary, null: false
      add :public_key, :binary, null: false
      add :sign_count, :integer, default: 0, null: false
      add :friendly_name, :string
      add :last_used_at, :utc_datetime
      add :aaguid, :binary  # Authenticator Attestation GUID

      timestamps()
    end

    create unique_index(:user_passkeys, [:credential_id])
    create index(:user_passkeys, [:user_id])
    
    alter table(:users) do
      add :passkey_enabled, :boolean, default: false
    end
  end
end
