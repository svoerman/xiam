defmodule XIAM.Repo.Migrations.CreateSettings do
  use Ecto.Migration

  def change do
    create table(:settings) do
      add :key, :string, null: false
      add :value, :text, null: false
      add :data_type, :string, null: false, default: "string"
      add :category, :string, null: false, default: "general"
      add :description, :text
      add :is_editable, :boolean, default: true

      timestamps()
    end

    create unique_index(:settings, [:key])
    create index(:settings, [:category])

    # Insert default settings
    execute """
    INSERT INTO settings (key, value, data_type, category, description, is_editable, inserted_at, updated_at)
    VALUES 
      ('mfa_required', 'false', 'boolean', 'security', 'Require multi-factor authentication for all users', true, now(), now()),
      ('mfa_grace_period_days', '7', 'integer', 'security', 'Number of days users have to enable MFA after being required', true, now(), now()),
      ('session_timeout_minutes', '60', 'integer', 'security', 'Session timeout in minutes', true, now(), now()),
      ('minimum_password_length', '12', 'integer', 'security', 'Minimum required password length', true, now(), now()),
      ('password_requires_uppercase', 'true', 'boolean', 'security', 'Password must contain at least one uppercase letter', true, now(), now()),
      ('password_requires_number', 'true', 'boolean', 'security', 'Password must contain at least one number', true, now(), now()),
      ('password_requires_special', 'true', 'boolean', 'security', 'Password must contain at least one special character', true, now(), now()),
      ('password_max_age_days', '90', 'integer', 'security', 'Maximum password age in days before requiring change', true, now(), now()),
      ('login_throttling_enabled', 'true', 'boolean', 'security', 'Enable login throttling to prevent brute force attacks', true, now(), now()),
      ('max_login_attempts', '5', 'integer', 'security', 'Maximum failed login attempts before throttling', true, now(), now()),
      ('login_throttle_period_minutes', '15', 'integer', 'security', 'Period of login throttling in minutes', true, now(), now()),
      ('system_name', 'XIAM', 'string', 'general', 'System name displayed in the UI and emails', true, now(), now()),
      ('support_email', 'support@example.com', 'string', 'general', 'Support email address', true, now(), now()),
      ('from_email', 'noreply@example.com', 'string', 'email', 'Default from address for system emails', true, now(), now()),
      ('email_footer_text', 'XIAM - Customer Identity and Access Management System', 'string', 'email', 'Text to include in email footers', true, now(), now()),
      ('audit_logs_retention_days', '365', 'integer', 'gdpr', 'Number of days to retain audit logs', true, now(), now()),
      ('consent_retention_days', '180', 'integer', 'gdpr', 'Number of days to retain revoked consent records', true, now(), now()),
      ('inactive_account_days', '730', 'integer', 'gdpr', 'Days after which inactive accounts will be anonymized', true, now(), now()),
      ('allow_account_deletion', 'true', 'boolean', 'gdpr', 'Allow users to delete their own accounts', true, now(), now()),
      ('delete_account_confirmation_days', '14', 'integer', 'gdpr', 'Number of days before account deletion is finalized', true, now(), now()),
      ('api_rate_limit', '100', 'integer', 'api', 'Default API rate limit per hour', true, now(), now()),
      ('api_token_expiry_days', '30', 'integer', 'api', 'Default API token expiry in days', true, now(), now()),
      ('default_user_role', 'user', 'string', 'users', 'Default role assigned to new users', true, now(), now()),
      ('allow_registration', 'true', 'boolean', 'users', 'Allow public user registration', true, now(), now())
    """
  end
end
