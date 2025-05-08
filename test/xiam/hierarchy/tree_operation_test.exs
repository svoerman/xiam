defmodule XIAM.Hierarchy.TreeOperationTest do
  alias XIAM.TestOutputHelper, as: Output
  use XIAM.DataCase, async: false
  
  alias XIAM.Hierarchy
  
  describe "is_descendant?/2" do
    test "correctly identifies descendant relationships" do
      # Use the HierarchyTestHelper for resilient test patterns
      XIAM.HierarchyTestHelper.ensure_applications_started()
      XIAM.HierarchyTestHelper.setup_resilient_connection()
      
      # Create nodes directly with Repo to avoid Hierarchy.create_node ownership issues
      # Parent node
      parent_name = "Parent #{XIAM.HierarchyTestHelper.unique_id()}"
      parent_path = parent_name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "_")
      
      parent = %XIAM.Hierarchy.Node{
        name: parent_name,
        node_type: "company",
        path: parent_path,
        metadata: %{"key" => "value"}
      } |> XIAM.Repo.insert!()
      assert parent.id != nil, "Failed to create parent node"
      
      # Child node
      child_name = "Child #{XIAM.HierarchyTestHelper.unique_id()}"
      child_path = "#{parent.path}.#{child_name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "_")}"
      
      child = %XIAM.Hierarchy.Node{
        name: child_name,
        node_type: "department",
        parent_id: parent.id,
        path: child_path,
        metadata: %{"key" => "value"}
      } |> XIAM.Repo.insert!()
      assert child.id != nil, "Failed to create child node"
      assert child.parent_id == parent.id, "Child not created with correct parent reference"
      
      # Grandchild node for deeper hierarchy testing
      grandchild_name = "Grandchild #{XIAM.HierarchyTestHelper.unique_id()}"
      grandchild_path = "#{child_path}.#{grandchild_name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "_")}"
      
      grandchild = %XIAM.Hierarchy.Node{
        name: grandchild_name,
        node_type: "team",
        parent_id: child.id,
        path: grandchild_path,
        metadata: %{"key" => "value"}
      } |> XIAM.Repo.insert!()
      
      # Test is_descendant? directly first using paths, which is the core of the function
      # Child is descendant of parent
      is_child_descendant = String.starts_with?(child.path, parent.path)
      assert is_child_descendant, "Child should be identified as descendant of parent by path"
      
      # Grandchild is descendant of parent
      is_grandchild_descendant = String.starts_with?(grandchild.path, parent.path)
      assert is_grandchild_descendant, "Grandchild should be identified as descendant of parent by path"
      
      # Grandchild is descendant of child
      is_grandchild_of_child = String.starts_with?(grandchild.path, child.path)
      assert is_grandchild_of_child, "Grandchild should be identified as descendant of child by path"
      
      # Parent is NOT descendant of child
      is_parent_descendant = String.starts_with?(parent.path, child.path)
      refute is_parent_descendant, "Parent should NOT be identified as descendant of child by path"
      
      # Child is NOT descendant of grandchild
      is_child_of_grandchild = String.starts_with?(child.path, grandchild.path)
      refute is_child_of_grandchild, "Child should NOT be identified as descendant of grandchild by path"
      
      # Now test the Hierarchy.is_descendant? function with resilient DB patterns
      result = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        Hierarchy.is_descendant?(child.id, parent.id)
      end, max_retries: 3)
      
      # Check the result with pattern matching to handle different return types
      case result do
        {:ok, true} -> :ok
        true -> :ok
        other -> 
          flunk("Expected Hierarchy.is_descendant? to return true for child->parent, got: #{inspect(other)}")
      end
      
      # Verify parent is not descendant of child
      result = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        Hierarchy.is_descendant?(parent.id, child.id)
      end, max_retries: 3)
      
      # Check the result with pattern matching
      case result do
        {:ok, false} -> :ok
        false -> :ok
        other -> 
          flunk("Expected Hierarchy.is_descendant? to return false for parent->child, got: #{inspect(other)}")
      end
    end
  end
  
  describe "move_subtree/2" do
    @tag timeout: 120_000  # Explicitly increase the test timeout for this potentially slow operation
    test "moves the subtree with all its children" do
      # Use the HierarchyTestHelper for resilient test patterns
      XIAM.HierarchyTestHelper.ensure_applications_started()
      XIAM.HierarchyTestHelper.setup_resilient_connection()
      
      # Create source parent
      source_parent_name = "Source Parent #{XIAM.HierarchyTestHelper.unique_id()}"
      source_parent_path = source_parent_name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "_")
      source_parent = %XIAM.Hierarchy.Node{
        name: source_parent_name,
        node_type: "company",
        path: source_parent_path
      } |> XIAM.Repo.insert!()
      assert source_parent.id != nil
      
      # Create target parent
      target_parent_name = "Target Parent #{XIAM.HierarchyTestHelper.unique_id()}"
      target_parent_path = target_parent_name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "_")
      target_parent = %XIAM.Hierarchy.Node{
        name: target_parent_name,
        node_type: "company",
        path: target_parent_path
      } |> XIAM.Repo.insert!()
      assert target_parent.id != nil
      
      # Create child node
      child_name = "Child #{XIAM.HierarchyTestHelper.unique_id()}"
      child_path = "#{source_parent_path}.#{child_name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "_")}"
      child = %XIAM.Hierarchy.Node{
        name: child_name,
        node_type: "department",
        parent_id: source_parent.id,
        path: child_path
      } |> XIAM.Repo.insert!()
      assert child.id != nil
      assert child.parent_id == source_parent.id
      
      # Create grandchild node
      grandchild_name = "Grandchild #{XIAM.HierarchyTestHelper.unique_id()}"
      grandchild_path = "#{child_path}.#{grandchild_name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "_")}"
      grandchild = %XIAM.Hierarchy.Node{
        name: grandchild_name,
        node_type: "team",
        parent_id: child.id,
        path: grandchild_path
      } |> XIAM.Repo.insert!()
      assert grandchild.id != nil
      assert grandchild.parent_id == child.id
      
      # Store original paths for verification
      child_original_path = child.path
      grandchild_original_path = grandchild.path
      
      # Perform resilient operations inside a transaction
      execute_result = XIAM.HierarchyTestHelper.execute_in_transaction(fn ->
        # Move the subtree using Hierarchy.move_subtree
        move_result = Hierarchy.move_subtree(child.id, target_parent.id)
        
        case move_result do
          {:ok, _} -> :ok
          :ok -> :ok
          {:error, :would_create_cycle} -> flunk("Move operation failed with :would_create_cycle error")
          other -> flunk("Move operation failed with unexpected error: #{inspect(other)}")
        end
      end)
      
      assert {:ok, :ok} = execute_result, "Transaction failed during move operation"
      
      # Get updated nodes to verify the changes
      updated_child = XIAM.Repo.get!(XIAM.Hierarchy.Node, child.id)
      updated_grandchild = XIAM.Repo.get!(XIAM.Hierarchy.Node, grandchild.id)
      
      # Verify nodes were updated correctly
      assert updated_child.parent_id == target_parent.id, 
        "Child node parent_id not updated, still #{updated_child.parent_id} instead of #{target_parent.id}"
      
      assert updated_child.path != child_original_path,
        "Child path should have changed after move"
      
      assert updated_grandchild.path != grandchild_original_path,
        "Grandchild path should have changed after move"
      
      assert String.starts_with?(updated_child.path, target_parent.path),
        "Child path should now start with target parent path"
      
      assert String.starts_with?(updated_grandchild.path, updated_child.path),
        "Grandchild path should start with new child path"
    end
    
    test "blocks cyclic references" do
      # Use the HierarchyTestHelper for resilient test patterns
      XIAM.HierarchyTestHelper.ensure_applications_started()
      XIAM.HierarchyTestHelper.setup_resilient_connection()
      
      # Create parent node
      parent_name = "Parent #{XIAM.HierarchyTestHelper.unique_id()}"
      parent_path = parent_name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "_")
      parent = %XIAM.Hierarchy.Node{
        name: parent_name,
        node_type: "company",
        path: parent_path
      } |> XIAM.Repo.insert!()
      
      # Create child node
      child_name = "Child #{XIAM.HierarchyTestHelper.unique_id()}"
      child_path = "#{parent_path}.#{child_name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "_")}"
      child = %XIAM.Hierarchy.Node{
        name: child_name,
        node_type: "department",
        parent_id: parent.id,
        path: child_path
      } |> XIAM.Repo.insert!()
      
      # Trying to move parent to be a child of its own child should fail
      move_result = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        Hierarchy.move_subtree(parent.id, child.id)
      end, max_retries: 3)
      
      # Handle the error result
      case move_result do
        {:ok, {:error, :would_create_cycle}} -> 
          Output.debug_print("DB operation failed, which prevented invalid move: :would_create_cycle")
          :ok
          
        {:error, error} when error == :would_create_cycle -> 
          Output.debug_print("DB operation failed, which prevented invalid move: :would_create_cycle")
          :ok
          
        other -> 
          flunk("Expected :would_create_cycle error but got: #{inspect(other)}")
      end
      
      # Verify that the relationship didn't change
      updated_parent = XIAM.Repo.get!(XIAM.Hierarchy.Node, parent.id)
      assert updated_parent.parent_id == nil,
        "Parent's parent_id should still be nil after failed cyclic move"
    end
  end
end
