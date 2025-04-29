defmodule XIAM.GDPR.TransactionHelper do
  @moduledoc """
  Helper functions for managing GDPR-related database transactions.
  
  Provides reusable patterns for transaction management with audit logging.
  """
  
  alias Ecto.Multi
  
  @doc """
  Adds audit logging to a multi transaction.
  
  ## Parameters
  - `multi` - The Multi transaction to add audit logging to
  - `action` - The action being performed, e.g., "user_anonymized"
  - `entity_id` - ID of the entity being acted upon
  - `metadata` - Optional metadata to include in the audit log
  
  ## Returns
  - Updated Multi with audit logging step added
  """
  def with_audit_log(multi, action, entity_id, metadata \\ %{}) do
    multi
    |> Multi.run(:audit_log, fn _repo, _changes ->
      XIAM.Jobs.AuditLogger.log_action(action, entity_id, metadata, "N/A")
      {:ok, true}
    end)
  end
  
  @doc """
  Creates a transaction that logs an action and performs a function.
  
  ## Parameters
  - `action` - The action being performed, e.g., "user_anonymized"
  - `entity_id` - ID of the entity being acted upon
  - `operation_name` - Name for the operation in the Multi
  - `operation_fun` - Function that returns a changeset or takes repo+changes
  - `options` - Optional parameters:
    - `:metadata` - Additional data for audit log
    - `:run_operation` - If true, operation_fun receives repo and changes
  
  ## Returns
  - Multi transaction ready to be executed
  """
  def create_transaction(action, entity_id, operation_name, operation_fun, options \\ []) do
    metadata = Keyword.get(options, :metadata, %{})
    run_operation = Keyword.get(options, :run_operation, false)
    
    multi = Multi.new()
    
    # Add operation
    multi = if run_operation do
      Multi.run(multi, operation_name, operation_fun)
    else
      Multi.update(multi, operation_name, operation_fun.())
    end
    
    # Add audit logging
    with_audit_log(multi, action, entity_id, metadata)
  end
end
