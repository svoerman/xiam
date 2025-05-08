defmodule XIAM.Hierarchy.NodeDeletionTest do
  @moduledoc """
  Tests for node deletion functionality in the hierarchy system.
  
  These tests verify that deleting nodes properly removes them and their descendants
  while maintaining the integrity of the remaining hierarchy.
  """
  
  use XIAM.ResilientTestCase
  
  alias XIAM.Hierarchy
  alias XIAM.Hierarchy.Node
  alias XIAM.Hierarchy.NodeManager
  alias XIAM.Repo
  
  setup do
    # First ensure the repo is started with explicit applications
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    {:ok, _} = Application.ensure_all_started(:postgrex)
    
    # Get a fresh database connection
    Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
    
    # Ensure repository is properly started
    XIAM.ResilientDatabaseSetup.ensure_repository_started()
    
    # Ensure ETS tables exist for Phoenix-related operations
    XIAM.ETSTestHelper.ensure_ets_tables_exist()
    
    :ok
  end
  
  @tag timeout: 120_000  # Explicitly increase the test timeout
  test "delete_node/1 deletes the node and its descendants" do
    # Use timestamp + random for truly unique identifiers
    timestamp = System.system_time(:millisecond)
    random_suffix = :rand.uniform(100_000)
    
    # Create parent node directly using Repo to avoid connection issues
    parent = %Node{
      name: "Parent_#{timestamp}_#{random_suffix}",
      node_type: "company",
      path: "parent_#{timestamp}_#{random_suffix}"
    } |> Repo.insert!()
    
    # Create child node
    child = %Node{
      name: "Child_#{timestamp}_#{random_suffix}",
      node_type: "department",
      parent_id: parent.id,
      path: "#{parent.path}.child_#{timestamp}_#{random_suffix}"
    } |> Repo.insert!()
    
    # Create grandchild node
    grandchild = %Node{
      name: "Grandchild_#{timestamp}_#{random_suffix}",
      node_type: "team",
      parent_id: child.id,
      path: "#{child.path}.grandchild_#{timestamp}_#{random_suffix}"
    } |> Repo.insert!()
    
    # Verify hierarchy structure
    assert child.parent_id == parent.id, "Child not created with correct parent"
    assert grandchild.parent_id == child.id, "Grandchild not created with correct parent"
    
    # Verify all three nodes exist before deletion
    pre_delete_parent = Repo.get(Node, parent.id)
    pre_delete_child = Repo.get(Node, child.id)
    pre_delete_grandchild = Repo.get(Node, grandchild.id)
    
    # All nodes should exist
    assert pre_delete_parent != nil, "Parent node not found before deletion"
    assert pre_delete_child != nil, "Child node not found before deletion"
    assert pre_delete_grandchild != nil, "Grandchild node not found before deletion"
    
    # Delete parent node directly using NodeManager to avoid connection issues
    # Note: NodeManager.delete_node expects a Node struct, not an ID
    result = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
      NodeManager.delete_node(parent)
    end, max_retries: 3, retry_delay: 100)
    
    # Verify deletion was successful
    case result do
      {:ok, {:ok, _}} -> :deletion_succeeded
      {:ok, _} -> :deletion_succeeded
      {:error, error} -> flunk("Failed to delete node: #{inspect(error)}")
      _ -> flunk("Unexpected result from delete_node: #{inspect(result)}")
    end
    
    # Force a delay to allow deletion to propagate
    Process.sleep(50)
    
    # After deletion, all nodes should be gone - use a fresh connection
    # to avoid process_dead errors
    post_delete_parent = Repo.get(Node, parent.id)
    post_delete_child = Repo.get(Node, child.id)
    post_delete_grandchild = Repo.get(Node, grandchild.id)
    
    # Assert all nodes are deleted
    assert post_delete_parent == nil, "Parent node still exists after deletion"
    assert post_delete_child == nil, "Child node still exists after deletion"
    assert post_delete_grandchild == nil, "Grandchild node still exists after deletion"
  end
  
  test "delete_node/1 maintains integrity of unrelated nodes" do
    # Use BootstrapHelper for the entire test
    XIAM.BootstrapHelper.with_bootstrap_protection(fn ->
      # Create two separate hierarchies to test that deleting one doesn't affect the other
      
      # First hierarchy
      {:ok, parent1} = XIAM.BootstrapHelper.safely_bootstrap(fn ->
        timestamp = System.system_time(:millisecond)
        random_suffix = :rand.uniform(100_000)
        parent_name = "Parent1_#{timestamp}_#{random_suffix}"
        
        Hierarchy.create_node(%{
          name: parent_name,
          node_type: "company"
        })
      end)
      
      {:ok, child1} = XIAM.BootstrapHelper.safely_bootstrap(fn ->
        timestamp = System.system_time(:millisecond)
        random_suffix = :rand.uniform(100_000)
        child_name = "Child1_#{timestamp}_#{random_suffix}"
        
        Hierarchy.create_node(%{
          name: child_name,
          node_type: "department",
          parent_id: parent1.id
        })
      end)
      
      # Second hierarchy (to remain untouched)
      {:ok, parent2} = XIAM.BootstrapHelper.safely_bootstrap(fn ->
        timestamp = System.system_time(:millisecond)
        random_suffix = :rand.uniform(100_000)
        parent_name = "Parent2_#{timestamp}_#{random_suffix}"
        
        Hierarchy.create_node(%{
          name: parent_name,
          node_type: "company"
        })
      end)
      
      {:ok, child2} = XIAM.BootstrapHelper.safely_bootstrap(fn ->
        timestamp = System.system_time(:millisecond)
        random_suffix = :rand.uniform(100_000)
        child_name = "Child2_#{timestamp}_#{random_suffix}"
        
        Hierarchy.create_node(%{
          name: child_name,
          node_type: "department",
          parent_id: parent2.id
        })
      end)
      
      # Verify both hierarchies exist
      {:ok, pre_delete_parent1} = XIAM.BootstrapHelper.safely_bootstrap(fn ->
        Repo.get(Node, parent1.id)
      end)
      
      {:ok, pre_delete_parent2} = XIAM.BootstrapHelper.safely_bootstrap(fn ->
        Repo.get(Node, parent2.id)
      end)
      
      assert pre_delete_parent1 != nil, "First parent not found before deletion"
      assert pre_delete_parent2 != nil, "Second parent not found before deletion"
      
      # Delete the first hierarchy
      {:ok, _} = XIAM.BootstrapHelper.safely_bootstrap(fn ->
        Hierarchy.delete_node(parent1)
      end)
      
      # Verify first hierarchy is gone
      {:ok, post_delete_parent1} = XIAM.BootstrapHelper.safely_bootstrap(fn ->
        Repo.get(Node, parent1.id)
      end)
      
      {:ok, post_delete_child1} = XIAM.BootstrapHelper.safely_bootstrap(fn ->
        Repo.get(Node, child1.id)
      end)
      
      assert post_delete_parent1 == nil, "First parent still exists after deletion"
      assert post_delete_child1 == nil, "First child still exists after deletion"
      
      # Verify second hierarchy remains untouched
      {:ok, post_delete_parent2} = XIAM.BootstrapHelper.safely_bootstrap(fn ->
        Repo.get(Node, parent2.id)
      end)
      
      {:ok, post_delete_child2} = XIAM.BootstrapHelper.safely_bootstrap(fn ->
        Repo.get(Node, child2.id)
      end)
      
      assert post_delete_parent2 != nil, "Second parent was deleted incorrectly"
      assert post_delete_child2 != nil, "Second child was deleted incorrectly"
      assert post_delete_parent2.id == parent2.id, "Second parent ID mismatch"
      assert post_delete_child2.id == child2.id, "Second child ID mismatch"
    end)
  end
end
