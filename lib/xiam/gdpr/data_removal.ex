defmodule XIAM.GDPR.DataRemoval do
  @moduledoc """
  Handles GDPR right to be forgotten by providing functionality to anonymize or delete user data.
  """
  
  alias XIAM.Repo
  alias XIAM.Users.User
  alias Ecto.Multi

  @doc """
  Anonymizes a user's data instead of completely removing it.
  This preserves audit logs and system integrity while respecting GDPR requirements.
  
  Returns {:ok, anonymized_user} on success, {:error, reason} on failure.
  """
  def anonymize_user(user_id) do
    user = Repo.get(User, user_id)
    
    if user do
      # Generate anonymized values
      anonymized_email = "anonymized_#{user_id}_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}@anonymous.example"
      
      # Create a multi operation to update user and related data
      Multi.new()
      |> Multi.update(:user, User.anonymize_changeset(user, %{
        email: anonymized_email,
        mfa_enabled: false,
        mfa_secret: nil,
        mfa_backup_codes: nil
      }))
      |> Multi.run(:audit_log, fn _repo, %{user: _user} ->
        XIAM.Jobs.AuditLogger.log_action("user_anonymized", user_id, %{}, "N/A")
        {:ok, true}
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{user: anonymized_user}} -> {:ok, anonymized_user}
        {:error, _failed_operation, failed_value, _changes} -> {:error, failed_value}
      end
    else
      {:error, :user_not_found}
    end
  end

  @doc """
  Completely deletes a user and all their associated data.
  This is a permanent operation and cannot be undone.
  
  Returns {:ok, deleted_user_id} on success, {:error, reason} on failure.
  """
  def delete_user(user_id) do
    user = Repo.get(User, user_id)
    
    if user do
      # Create a multi operation to delete user and all related data
      # The database cascade delete will handle most relations
      Multi.new()
      |> Multi.delete(:user, user)
      |> Multi.run(:audit_log, fn _repo, _changes ->
        # Store audit log in a separate system to maintain compliance record
        XIAM.Jobs.AuditLogger.log_action("user_deleted", user_id, %{}, "N/A")
        {:ok, true}
      end)
      |> Repo.transaction()
      |> case do
        {:ok, _changes} -> {:ok, user_id}
        {:error, _failed_operation, failed_value, _changes} -> {:error, failed_value}
      end
    else
      {:error, :user_not_found}
    end
  end
end
