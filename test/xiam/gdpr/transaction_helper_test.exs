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
    # Setup to ensure mocks are properly initialized for each test
    setup do
      # Try to unload any existing mocks, ignore errors if they don't exist yet
      try do
        :meck.unload(AuditLogger)
      catch
        _kind, _reason -> :ok
      end
      
      # Set up fresh mocks for each test
      :meck.new(AuditLogger, [:passthrough])
      :meck.expect(AuditLogger, :log_action, fn _, _, _, _ -> {:ok, true} end)
      
      on_exit(fn ->
        # Always try to clean up the mock, ignore errors
        try do
          :meck.unload(AuditLogger)
        catch
          _kind, _reason -> :ok
        end
      end)
      
      :ok
    end
    
    test "adds audit logging to a multi transaction" do
      # Setup
      multi = Multi.new()
      action = "test_action"
      entity_id = 42
      metadata = %{key: "value"}
      
      # Execute
      result_multi = TransactionHelper.with_audit_log(multi, action, entity_id, metadata)
      
      # Verify the multi contains the expected operations
      assert Enum.any?(result_multi.operations, fn {key, _value} -> key == :audit_log end)
    end
  end
  
  describe "create_transaction/5" do
    # Setup to ensure mocks are properly initialized for each test
    setup do
      # Try to unload any existing mocks, ignore errors if they don't exist yet
      try do
        :meck.unload(AuditLogger)
      catch
        _kind, _reason -> :ok
      end
      
      # Set up fresh mocks for each test
      :meck.new(AuditLogger, [:passthrough])
      :meck.expect(AuditLogger, :log_action, fn _action, _entity_id, _metadata, _conn -> 
        {:ok, true} 
      end)
      
      on_exit(fn ->
        # Always try to clean up the mock, ignore errors
        try do
          :meck.unload(AuditLogger)
        catch
          _kind, _reason -> :ok
        end
      end)
      
      :ok
    end
    
    test "creates a transaction with update operation" do
      # Setup
      action = "test_action"
      entity_id = 42
      operation_name = :test_operation
      test_changeset = %Ecto.Changeset{} # Empty changeset for testing
      
      # Create an operation function that returns a changeset
      operation_fun = fn -> test_changeset end
      
      # Override the mock expectation for this specific test if needed
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
      result_value = {:ok, "test result"}
      
      # Create an operation function that takes 2 args (repo and changes) as expected by Ecto.Multi.run
      operation_fun = fn _repo, _changes -> result_value end
      
      # Override the mock expectation for this specific test if needed
      :meck.expect(AuditLogger, :log_action, fn action, entity_id, metadata, _ -> 
        # Check that the parameters match what we expect
        assert action == "test_action"
        assert entity_id == 42
        assert metadata == %{additional: "data"}
        {:ok, true} 
      end)
      
      # Execute with run_operation: true and custom metadata
      result_multi = TransactionHelper.create_transaction(
        action, entity_id, operation_name, operation_fun,
        run_operation: true, metadata: %{additional: "data"}
      )
      
      # Verify the multi contains both operations
      assert Enum.any?(result_multi.operations, fn {key, _value} -> key == operation_name end)
      assert Enum.any?(result_multi.operations, fn {key, _value} -> key == :audit_log end)
    end
  end
end
