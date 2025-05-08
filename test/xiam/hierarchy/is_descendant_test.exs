defmodule XIAM.Hierarchy.IsDescendantTest do
  use XIAM.DataCase, async: false

  alias XIAM.Hierarchy
  # Only keep the aliases we actually use

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
      # Root node
      root_result = create_node("Root_#{timestamp}_#{:rand.uniform(100_000)}", "organization", nil)
      {:ok, root} = extract_node_result(root_result)
      
      # Direct child of root
      child_result = create_node("Child_#{timestamp}_#{:rand.uniform(100_000)}", "department", root.id)
      {:ok, child} = extract_node_result(child_result)
      
      # Grandchild (child of child)
      grandchild_result = create_node("Grandchild_#{timestamp}_#{:rand.uniform(100_000)}", "team", child.id)
      {:ok, grandchild} = extract_node_result(grandchild_result)
      
      # Sibling (another direct child of root, not related to the first child)
      sibling_result = create_node("Sibling_#{timestamp}_#{:rand.uniform(100_000)}", "department", root.id)
      {:ok, sibling} = extract_node_result(sibling_result)
      
      # Return the created hierarchy
      %{
        root: root,
        child: child,
        grandchild: grandchild,
        sibling: sibling
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

  describe "is_descendant?/2" do
    test "correctly identifies direct parent-child relationships", %{root: root, child: child} do
      # Test if child is a descendant of root (direct parent-child)
      # Note: is_descendant? expects node IDs, not node structs
      result = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        Hierarchy.is_descendant?(child.id, root.id)
      end, max_retries: 3)
      
      # Extract the boolean result from potentially nested structure
      is_descendant = case result do
        {:ok, {:ok, bool}} -> bool
        {:ok, bool} when is_boolean(bool) -> bool
        bool when is_boolean(bool) -> bool
        _ -> flunk("Unexpected result format from is_descendant?: #{inspect(result)}")
      end
      
      # Assert the direct parent-child relationship
      assert is_descendant, "Child should be identified as a descendant of its direct parent"
    end
    
    test "correctly identifies indirect descendant relationships", %{root: root, grandchild: grandchild} do
      # Test if grandchild is a descendant of root (indirect, two levels deep)
      # Pass node IDs instead of node structs
      result = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        Hierarchy.is_descendant?(grandchild.id, root.id)
      end, max_retries: 3)
      
      # Extract the boolean result
      is_descendant = case result do
        {:ok, {:ok, bool}} -> bool
        {:ok, bool} when is_boolean(bool) -> bool
        bool when is_boolean(bool) -> bool
        _ -> flunk("Unexpected result format from is_descendant?: #{inspect(result)}")
      end
      
      # Assert the indirect descendant relationship
      assert is_descendant, "Grandchild should be identified as a descendant of its grandparent"
    end
    
    test "correctly identifies non-descendant relationships", %{child: child, sibling: sibling} do
      # Test if sibling is a descendant of child (they are not related)
      # Use node IDs rather than node structs
      result = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        Hierarchy.is_descendant?(sibling.id, child.id)
      end, max_retries: 3)
      
      # Extract the boolean result
      is_descendant = case result do
        {:ok, {:ok, bool}} -> bool
        {:ok, bool} when is_boolean(bool) -> bool
        bool when is_boolean(bool) -> bool
        _ -> flunk("Unexpected result format from is_descendant?: #{inspect(result)}")
      end
      
      # Assert the non-descendant relationship
      refute is_descendant, "Sibling should not be identified as a descendant of another child"
    end
    
    test "a node is not a descendant of itself", %{root: root} do
      # Test if root is a descendant of itself (should be false)
      # Use node ID rather than the node struct
      result = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        Hierarchy.is_descendant?(root.id, root.id)
      end, max_retries: 3)
      
      # Extract the boolean result
      is_descendant = case result do
        {:ok, {:ok, bool}} -> bool
        {:ok, bool} when is_boolean(bool) -> bool
        bool when is_boolean(bool) -> bool
        _ -> flunk("Unexpected result format from is_descendant?: #{inspect(result)}")
      end
      
      # Assert that a node is not a descendant of itself
      refute is_descendant, "A node should not be considered a descendant of itself"
    end
  end
end
