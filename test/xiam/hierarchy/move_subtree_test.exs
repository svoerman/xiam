defmodule XIAM.Hierarchy.MoveSubtreeTest do
  use XIAM.DataCase, async: false

  alias XIAM.Hierarchy
  alias XIAM.Hierarchy.Node
  alias XIAM.Repo

  # Setup block to ensure proper database initialization with enhanced resilience
  setup do
    # Start all required applications explicitly
    # This is crucial for test stability based on our memory of resilient test patterns
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    {:ok, _} = Application.ensure_all_started(:postgrex)
    
    # Ensure repository is properly started
    XIAM.ResilientDatabaseSetup.ensure_repository_started()
    
    # Set explicit sandbox mode for better connection management
    Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
    
    # Ensure we have a fresh database connection
    Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo)
    
    # Ensure ETS tables exist for cache operations
    XIAM.ETSTestHelper.ensure_ets_tables_exist()
    
    # Use a proper transaction for creating test data
    test_data_result = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
      # Use timestamp + random for truly unique identifiers
      timestamp = System.system_time(:millisecond)
      
      # Create a hierarchy of nodes for testing
      # Root node (e.g., Organization)
      root_result = create_node("Root_#{timestamp}_#{:rand.uniform(100_000)}", "organization", nil)
      {:ok, root} = extract_node_result(root_result)
      
      # Two branches under root (e.g., Parent1 and Parent2)
      parent1_result = create_node("Parent1_#{timestamp}_#{:rand.uniform(100_000)}", "company", root.id)
      {:ok, parent1} = extract_node_result(parent1_result)
      
      parent2_result = create_node("Parent2_#{timestamp}_#{:rand.uniform(100_000)}", "company", root.id)
      {:ok, parent2} = extract_node_result(parent2_result)
      
      # Child under Parent1
      child_result = create_node("Child_#{timestamp}_#{:rand.uniform(100_000)}", "department", parent1.id)
      {:ok, child} = extract_node_result(child_result)
      
      # Grandchild under Child
      grandchild_result = create_node("Grandchild_#{timestamp}_#{:rand.uniform(100_000)}", "team", child.id)
      {:ok, grandchild} = extract_node_result(grandchild_result)
      
      # Return the created hierarchy
      %{
        root: root,
        parent1: parent1,
        parent2: parent2,
        child: child,
        grandchild: grandchild
      }
    end, max_retries: 3, retry_delay: 100)
    
    # Extract the test data from potentially nested result
    case test_data_result do
      {:ok, data} when is_map(data) -> data
      data when is_map(data) -> data
      _ -> flunk("Failed to create test hierarchy: #{inspect(test_data_result)}")
    end
  end
  
  # Helper function to create a node with error handling
  defp create_node(name, node_type, parent_id) do
    XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
      Hierarchy.create_node(%{
        name: name,
        node_type: node_type,
        parent_id: parent_id,
        metadata: %{"key" => "value"}
      })
    end, max_retries: 3, retry_delay: 100)
  end
  
  # Helper to extract node from potentially nested result patterns
  defp extract_node_result(result) do
    case result do
      {:ok, {:ok, node}} -> {:ok, node}
      {:ok, node} -> {:ok, node}
      _ -> flunk("Unexpected node result format: #{inspect(result)}")
    end
  end

  describe "move_subtree/2" do
    test "moves the subtree with all its children", %{parent1: parent1, parent2: parent2, child: child, grandchild: grandchild} do
      # Remember original paths for verification
      child_original_path = child.path
      grandchild_original_path = grandchild.path
      
      # Verify initial parent-child relationships
      assert child.parent_id == parent1.id, "Child should initially be under parent1"
      
      # Execute move_subtree operation with resilient pattern
      # Use node IDs instead of node structs
      move_result = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        Hierarchy.move_subtree(child.id, parent2.id)
      end, max_retries: 3, retry_delay: 100)
      
      # Verify the move operation succeeded
      case move_result do
        {:ok, {:ok, _}} -> :ok
        {:ok, _} -> :ok
        other -> flunk("Failed to move subtree: #{inspect(other)}")
      end
      
      # Reload nodes after move to verify changes
      # This pattern ensures we're fetching fresh data from the database
      updated_child_result = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        Repo.get(Node, child.id)
      end)
      
      # Extract the node from the result
      updated_child = case updated_child_result do
        {:ok, node} -> node
        node when is_struct(node, Node) -> node
        _ -> flunk("Failed to get updated child: #{inspect(updated_child_result)}")
      end
      
      # Similarly for grandchild
      updated_grandchild_result = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        Repo.get(Node, grandchild.id)
      end)
      
      # Extract the node from the result
      updated_grandchild = case updated_grandchild_result do
        {:ok, node} -> node
        node when is_struct(node, Node) -> node
        _ -> flunk("Failed to get updated grandchild: #{inspect(updated_grandchild_result)}")
      end
      
      # Verify parent has changed
      assert updated_child.parent_id == parent2.id,
        "Child should now be under parent2"
      
      # Verify paths have been updated
      refute updated_child.path == child_original_path,
        "Child path should have changed from original '#{child_original_path}'"
      
      refute updated_grandchild.path == grandchild_original_path, 
        "Grandchild path should have changed from original '#{grandchild_original_path}'"
        
      # Verify the new paths reflect the new hierarchy
      assert String.starts_with?(updated_grandchild.path, updated_child.path),
        "Grandchild path '#{updated_grandchild.path}' should start with child path '#{updated_child.path}'"
    end
    
    test "prevents moving a node to its own descendant", %{child: child, grandchild: grandchild} do
      # Try to move the parent (child) under its own child (grandchild)
      # This should fail with an appropriate error
      # Use node IDs instead of node structs
      move_result = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        Hierarchy.move_subtree(child.id, grandchild.id)
      end, max_retries: 3, retry_delay: 100)
      
      # Verify the operation failed with an appropriate error
      case move_result do
        {:ok, {:error, changeset}} ->
          # Verify there's an error related to moving to descendant
          errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Enum.reduce(opts, msg, fn {key, value}, acc ->
              String.replace(acc, "%{#{key}}", to_string(value))
            end)
          end)
          
          # Assert the error message contains something about circular reference or descendant
          assert errors[:parent_id] || errors[:base], 
            "Expected error about moving to descendant, got: #{inspect(errors)}"
            
        other ->
          # If we got a different error pattern, check it's still failing appropriately
          case other do
            {:error, _} -> :ok  # Different error format but still an error
            _ -> flunk("Expected move_subtree to fail with error, got: #{inspect(other)}")
          end
      end
      
      # Verify hierarchy hasn't changed
      unchanged_child_result = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        Repo.get(Node, child.id)
      end)
      
      # Extract the node from the result
      unchanged_child = case unchanged_child_result do
        {:ok, node} -> node
        node when is_struct(node, Node) -> node
        _ -> flunk("Failed to get unchanged child: #{inspect(unchanged_child_result)}")
      end
      
      # Parent ID should remain unchanged
      assert unchanged_child.parent_id == child.parent_id,
        "Child's parent_id should remain unchanged after invalid move attempt"
    end
  end
end
