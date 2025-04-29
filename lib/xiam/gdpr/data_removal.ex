defmodule XIAM.GDPR.DataRemoval do
  @moduledoc """
  Handles GDPR right to be forgotten by providing functionality to anonymize or delete user data.
  """
  
  alias XIAM.Repo
  alias XIAM.Users.User
  alias XIAM.GDPR.TransactionHelper

  @doc """
  Anonymizes a user's data instead of completely removing it.
  This preserves audit logs and system integrity while respecting GDPR requirements.
  
  Returns {:ok, anonymized_user} on success, {:error, reason} on failure.
  """
  def anonymize_user(user_id) do
    with {:ok, user} <- get_user(user_id),
         {:ok, result} <- perform_anonymization(user) do
      {:ok, result.user}
    end
  end

  @doc """
  Completely deletes a user and all their associated data.
  This is a permanent operation and cannot be undone.
  
  Returns {:ok, deleted_user_id} on success, {:error, reason} on failure.
  """
  def delete_user(user_id) do
    with {:ok, user} <- get_user(user_id),
         {:ok, _result} <- perform_deletion(user) do
      {:ok, user_id}
    end
  end
  
  # Private helpers
  
  defp get_user(user_id) do
    case Repo.get(User, user_id) do
      nil -> {:error, :user_not_found}
      user -> {:ok, user}
    end
  end
  
  defp perform_anonymization(user) do
    # Generate anonymized values
    anonymized_email = "anonymized_#{user.id}_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}@anonymous.example"
    
    # Create changeset
    changeset = User.anonymize_changeset(user, %{
      email: anonymized_email,
      mfa_enabled: false,
      mfa_secret: nil,
      mfa_backup_codes: nil
    })
    
    # Execute transaction with audit logging
    result = TransactionHelper.create_transaction(
      "user_anonymized", 
      user.id, 
      :user, 
      fn -> changeset end
    )
    |> Repo.transaction()
    
    # Process the result to match the original format
    case result do
      {:ok, changes} -> {:ok, changes}
      {:error, :user, changeset, _changes} -> {:error, changeset}
    end
  end
  
  defp perform_deletion(user) do
    # Create deletion transaction with additional metadata
    result = TransactionHelper.create_transaction(
      "user_deleted",
      user.id,
      :user,
      fn repo, _changes -> 
        case repo.delete(user) do
          {:ok, deleted} -> {:ok, deleted}
          {:error, changeset} -> {:error, changeset}
        end
      end,
      run_operation: true,
      metadata: %{email: user.email}
    )
    |> Repo.transaction()
    
    # Process the result to match the original format
    case result do
      {:ok, changes} -> {:ok, changes}
      {:error, :user, changeset, _changes} -> {:error, changeset}
    end
  end
end
