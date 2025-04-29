defmodule XIAM.GDPR.TransactionHelperTest do
  use XIAM.DataCase
  
  alias XIAM.GDPR.TransactionHelper
  alias XIAM.Jobs.AuditLogger
  alias Ecto.Multi
  
  setup do
    # We'll use meck for mocking
    :ok
  end
  
  describe "with_audit_log/4" do
    test "adds audit logging to a multi transaction" do
      # Setup
      multi = Multi.new()
      action = "test_action"
      entity_id = 42
      metadata = %{key: "value"}
      
      # Set up meck mock for AuditLogger
      :meck.new(AuditLogger, [:passthrough])
      :meck.expect(AuditLogger, :log_action, fn _, _, _, _ -> {:ok, true} end)
      
      # Execute
      result_multi = TransactionHelper.with_audit_log(multi, action, entity_id, metadata)
      
      # Verify the multi contains the expected operations
      assert Enum.any?(result_multi.operations, fn {key, _value} -> key == :audit_log end)
    end
  end
  
  describe "create_transaction/5" do
    test "creates a transaction with update operation" do
      # Setup
      action = "test_action"
      entity_id = 42
      operation_name = :test_operation
      test_changeset = %Ecto.Changeset{} # Empty changeset for testing
      
      # Create an operation function that returns a changeset
      operation_fun = fn -> test_changeset end
      
      # Set up meck mock for AuditLogger
      :meck.new(AuditLogger, [:passthrough])
      :meck.expect(AuditLogger, :log_action, fn action, entity_id, metadata, _ -> 
        # Check that the parameters match what we expect
        assert action == "test_action"
        assert entity_id == 42
        assert metadata == %{}
        {:ok, true} 
      end)
      
      try do
        # Execute
        result_multi = TransactionHelper.create_transaction(
          action, entity_id, operation_name, operation_fun
        )
        
        # Verify the multi contains both operations
        assert Enum.any?(result_multi.operations, fn {key, _value} -> key == operation_name end)
        assert Enum.any?(result_multi.operations, fn {key, _value} -> key == :audit_log end)
      after
        :meck.unload(AuditLogger)
      end
    end
    
    test "creates a transaction with run operation" do
      # Setup
      action = "test_action"
      entity_id = 42
      operation_name = :test_operation
      
      # Create an operation function that takes repo and changes
      operation_fun = fn _repo, _changes -> {:ok, true} end
      
      # Set up meck mock for AuditLogger
      :meck.new(AuditLogger, [:passthrough])
      :meck.expect(AuditLogger, :log_action, fn action, entity_id, metadata, _ -> 
        # Check that the parameters match what we expect
        assert action == "test_action"
        assert entity_id == 42
        assert metadata == %{additional: "data"}
        {:ok, true} 
      end)
      
      try do
        # Execute with run_operation: true and custom metadata
        result_multi = TransactionHelper.create_transaction(
          action, entity_id, operation_name, operation_fun,
          run_operation: true, metadata: %{additional: "data"}
        )
        
        # Verify the multi contains both operations
        assert Enum.any?(result_multi.operations, fn {key, _value} -> key == operation_name end)
        assert Enum.any?(result_multi.operations, fn {key, _value} -> key == :audit_log end)
      after
        :meck.unload(AuditLogger)
      end
    end
  end
end
