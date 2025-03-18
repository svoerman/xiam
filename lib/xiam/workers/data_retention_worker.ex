defmodule XIAM.Workers.DataRetentionWorker do
  @moduledoc """
  Oban worker for enforcing data retention policies as per GDPR requirements.
  This worker handles deletion of expired data, anonymization of inactive accounts,
  and enforcement of data retention policies.
  """
  use Oban.Worker, queue: :gdpr, max_attempts: 3

  import Ecto.Query
  alias XIAM.Repo
  alias XIAM.Users.User
  alias XIAM.Audit
  alias XIAM.Consent.ConsentRecord

  @impl Oban.Worker
  def perform(_job) do
    run_data_retention_tasks()
    :ok
  end

  @doc """
  Schedules a data retention job.
  """
  def schedule() do
    %{id: "data_retention"}
    |> __MODULE__.new()
    |> Oban.insert()
  end

  @doc """
  Run the data retention tasks to enforce GDPR policies.
  """
  def run_data_retention_tasks do
    # Log the start of data retention process
    Audit.log_action("data_retention_started", :system, "system")

    # Remove expired audit logs
    delete_expired_audit_logs()

    # Anonymize inactive accounts based on policy
    anonymize_inactive_accounts()

    # Delete expired consent records
    delete_expired_consent_records()

    # Handle user deletion requests
    process_deletion_requests()

    # Log completion of data retention process
    Audit.log_action("data_retention_completed", :system, "system")
  end

  # Delete audit logs older than the retention period
  defp delete_expired_audit_logs do
    # Default retention period is 1 year (365 days)
    retention_days = Application.get_env(:xiam, :audit_logs_retention_days, 365)
    retention_date = DateTime.utc_now() |> DateTime.add(-retention_days * 24 * 60 * 60, :second)

    # Get count of logs to be deleted for auditing
    count_query = from a in "audit_logs",
                 where: a.inserted_at < ^retention_date,
                 select: count(a.id)
    
    delete_count = Repo.one(count_query)

    if delete_count > 0 do
      # Perform the deletion
      {deleted, _} = Repo.delete_all(
        from a in "audit_logs",
        where: a.inserted_at < ^retention_date
      )

      # Log the deletion operation
      Audit.log_action(
        "audit_logs_cleanup",
        :system,
        "audit_logs",
        nil,
        %{deleted_count: deleted, older_than_days: retention_days}
      )
    end
  end

  # Anonymize user accounts that have been inactive for the specified period
  defp anonymize_inactive_accounts do
    # Default inactive period is 2 years (730 days)
    inactive_days = Application.get_env(:xiam, :inactive_account_days, 730)
    inactive_date = DateTime.utc_now() |> DateTime.add(-inactive_days * 24 * 60 * 60, :second)

    # Find inactive users (not logged in since the inactive date)
    inactive_users_query = from u in User,
                           where: u.last_sign_in_at < ^inactive_date,
                           where: u.anonymized == false,
                           where: u.admin == false

    inactive_users = Repo.all(inactive_users_query)

    # Anonymize each inactive user
    Enum.each(inactive_users, fn user ->
      anonymize_user(user)
    end)
  end

  # Anonymize a user's personal data
  defp anonymize_user(user) do
    # Don't anonymize admin users as a safety measure
    if user.admin do
      {:error, :cannot_anonymize_admin}
    else
      anonymized_email = "anonymized-#{user.id}@example.com"
      
      # Update the user with anonymized data
      user
      |> Ecto.Changeset.change(%{
        email: anonymized_email,
        name: "Anonymized User",
        anonymized: true
      })
      |> Repo.update()
      
      # Log the anonymization
      Audit.log_action(
        "user_anonymized",
        :system,
        "user",
        user.id,
        %{reason: "inactive_account"}
      )
    end
  end

  # Delete expired consent records
  defp delete_expired_consent_records do
    # Only delete revoked consent records older than retention period
    retention_days = Application.get_env(:xiam, :consent_retention_days, 180)
    retention_date = DateTime.utc_now() |> DateTime.add(-retention_days * 24 * 60 * 60, :second)

    # Find expired revoked consent records
    query = from c in ConsentRecord,
            where: c.revoked_at < ^retention_date,
            select: c.id
    
    consent_ids = Repo.all(query)
    
    if length(consent_ids) > 0 do
      # Delete the expired consent records
      {deleted, _} = Repo.delete_all(
        from c in ConsentRecord,
        where: c.id in ^consent_ids
      )
      
      # Log the deletion
      Audit.log_action(
        "consent_records_cleanup",
        :system,
        "consent_records",
        nil,
        %{deleted_count: deleted, older_than_days: retention_days}
      )
    end
  end

  # Process user deletion requests
  defp process_deletion_requests do
    # Get all users that have requested deletion
    deletion_requests_query = from u in User,
                             where: u.deletion_requested == true
    
    users_to_delete = Repo.all(deletion_requests_query)
    
    # Delete each user that requested deletion
    Enum.each(users_to_delete, fn user ->
      # Log the deletion
      Audit.log_action(
        "user_deleted",
        :system,
        "user",
        user.id,
        %{reason: "user_requested"}
      )
      
      # Delete the user
      Repo.delete(user)
    end)
  end
end
