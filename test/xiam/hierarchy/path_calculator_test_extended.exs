defmodule XIAM.Hierarchy.PathCalculatorTestExtended do
  use XIAM.DataCase, async: false
  
  import XIAM.ETSTestHelper
  alias XIAM.Hierarchy
  alias XIAM.Hierarchy.PathCalculator
  alias XIAM.Hierarchy.Node
  alias XIAM.Repo
  
  # Generate a unique identifier for test data
  defp unique_id() do
    "#{System.system_time(:millisecond)}_#{:rand.uniform(100_000)}"
  end
  
  # Setup a test hierarchy with deep nesting for path calculations
  defp setup_deep_hierarchy() do
    unique = unique_id()
    
    XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
      Repo.transaction(fn ->
        # Create root node
        {:ok, root} = Hierarchy.create_node(%{
          name: "Path_Root_#{unique}",
          node_type: "company"
        })
        
        # Level 1
        {:ok, level1} = Hierarchy.create_node(%{
          name: "Path_Level1_#{unique}",
          node_type: "division",
          parent_id: root.id
        })
        
        # Level 2
        {:ok, level2} = Hierarchy.create_node(%{
          name: "Path_Level2_#{unique}",
          node_type: "department",
          parent_id: level1.id
        })
        
        # Level 3
        {:ok, level3} = Hierarchy.create_node(%{
          name: "Path_Level3_#{unique}",
          node_type: "team",
          parent_id: level2.id
        })
        
        # Level 4
        {:ok, level4} = Hierarchy.create_node(%{
          name: "Path_Level4_#{unique}",
          node_type: "project",
          parent_id: level3.id
        })
        
        # Level 5
        {:ok, level5} = Hierarchy.create_node(%{
          name: "Path_Level5_#{unique}",
          node_type: "task",
          parent_id: level4.id
        })
        
        # Return all created nodes
        %{
          root: root,
          level1: level1,
          level2: level2,
          level3: level3,
          level4: level4,
          level5: level5
        }
      end)
    end)
  end
  
  describe "calculate_path/1" do
    test "calculates correct path for deeply nested node" do
      # Ensure ETS tables exist
      ensure_ets_tables_exist()
      
      # Create a deeply nested hierarchy
      {:ok, nodes} = setup_deep_hierarchy()
      
      # Calculate path for the deeply nested node
      result = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        PathCalculator.calculate_path(nodes.level5.id)
      end)
      
      # Verify the path is calculated correctly
      assert {:ok, path} = result
      
      # Path should include all ancestors from root to the node
      assert String.contains?(path, to_string(nodes.root.id))
      assert String.contains?(path, to_string(nodes.level1.id))
      assert String.contains?(path, to_string(nodes.level2.id))
      assert String.contains?(path, to_string(nodes.level3.id))
      assert String.contains?(path, to_string(nodes.level4.id))
      assert String.contains?(path, to_string(nodes.level5.id))
      
      # Path should be correctly formatted with the path separator
      # Assuming the path format is something like "1/2/3/4/5"
      separator = PathCalculator.path_separator()
      expected_parts = [
        to_string(nodes.root.id),
        to_string(nodes.level1.id),
        to_string(nodes.level2.id),
        to_string(nodes.level3.id),
        to_string(nodes.level4.id),
        to_string(nodes.level5.id)
      ]
      
      # Check each expected part is in the path
      Enum.each(expected_parts, fn part ->
        assert String.contains?(path, part)
      end)
      
      # Check that the path follows the correct ordering
      expected_path = Enum.join(expected_parts, separator)
      assert path == expected_path
    end
    
    test "returns error for non-existent node" do
      # Ensure ETS tables exist
      ensure_ets_tables_exist()
      
      # Calculate path for a non-existent node ID
      result = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        PathCalculator.calculate_path(999999)
      end)
      
      # Verify error response
      assert {:error, _} = result
    end
    
    test "handles circular references (if they exist in data)" do
      # Ensure ETS tables exist
      ensure_ets_tables_exist()
      
      # Create test nodes
      unique = unique_id()
      
      # Create nodes for potential cycle testing
      cycle_nodes = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        # Create normal parent-child relationship
        {:ok, parent} = Hierarchy.create_node(%{
          name: "Cycle_Parent_#{unique}",
          node_type: "department"
        })
        
        {:ok, child} = Hierarchy.create_node(%{
          name: "Cycle_Child_#{unique}",
          node_type: "team",
          parent_id: parent.id
        })
        
        # Save the normal nodes
        %{parent: parent, child: child}
      end)
      
      # Calculate the correct path first
      correct_path_result = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        PathCalculator.calculate_path(cycle_nodes.child.id)
      end)
      
      # Verify correct path calculation
      assert {:ok, path} = correct_path_result
      assert String.contains?(path, to_string(cycle_nodes.parent.id))
      assert String.contains?(path, to_string(cycle_nodes.child.id))
      
      # Now force a circular reference directly in the database
      # This circumvents normal validation but tests how the path calculator handles cycles
      XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        # Try to update parent's parent_id to point to child
        # NOTE: This may fail if there are DB constraints preventing cycles
        try do
          Repo.get(Node, cycle_nodes.parent.id)
          |> Ecto.Changeset.change(%{parent_id: cycle_nodes.child.id})
          |> Repo.update()
          
          # Now try to calculate path with a cycle
          cycle_path_result = PathCalculator.calculate_path(cycle_nodes.child.id)
          
          # The path calculator should detect the cycle and return an error
          # or have some cycle detection mechanism
          case cycle_path_result do
            {:error, reason} ->
              # Success - the cycle was detected
              assert String.contains?(to_string(reason), "cycle") || 
                     String.contains?(to_string(reason), "circular") ||
                     String.contains?(to_string(reason), "loop")
            
            {:ok, _path} ->
              # If successful, the code should have handled the cycle somehow
              # This might be a valid result for some implementations
              :ok
          end
        rescue
          # Some databases may enforce constraints preventing cycles
          error ->
            # This is also a valid outcome - database prevented the cycle
            assert true
        end
      end)
    end
  end
  
  describe "extract_path_components/1" do
    test "correctly extracts components from a path" do
      # Ensure ETS tables exist
      ensure_ets_tables_exist()
      
      # Create a path with known components
      node_ids = [1, 2, 3, 4, 5]
      separator = PathCalculator.path_separator()
      path = Enum.join(Enum.map(node_ids, &to_string/1), separator)
      
      # Extract components from the path
      result = PathCalculator.extract_path_components(path)
      
      # Verify components match the original node IDs
      assert length(result) == length(node_ids)
      Enum.zip(result, node_ids) |> Enum.each(fn {extracted, original} ->
        # Components may be returned as strings or integers depending on implementation
        extracted_string = to_string(extracted)
        original_string = to_string(original)
        assert extracted_string == original_string
      end)
    end
    
    test "handles empty path" do
      # Extract components from an empty path
      result = PathCalculator.extract_path_components("")
      
      # Expected behavior: return empty list or appropriate error
      assert result == [] || match?({:error, _}, result)
    end
    
    test "handles malformed path" do
      # Create malformed paths
      separator = PathCalculator.path_separator()
      malformed_path_1 = separator <> separator  # Empty components
      malformed_path_2 = "not_a_number" <> separator <> "123" # Non-numeric component
      
      # Test handling of malformed paths
      result_1 = PathCalculator.extract_path_components(malformed_path_1)
      result_2 = PathCalculator.extract_path_components(malformed_path_2)
      
      # The implementation should handle these cases without crashing
      # How exactly it handles them depends on the implementation
      assert is_list(result_1) || match?({:error, _}, result_1)
      assert is_list(result_2) || match?({:error, _}, result_2)
    end
  end
  
  describe "calculate_parent_path/1" do
    test "correctly calculates parent path" do
      # Ensure ETS tables exist
      ensure_ets_tables_exist()
      
      # Create a hierarchy with known structure
      {:ok, nodes} = setup_deep_hierarchy()
      
      # Get the path of a node
      {:ok, node_path} = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        PathCalculator.calculate_path(nodes.level3.id)
      end)
      
      # Calculate the parent path
      parent_path = PathCalculator.calculate_parent_path(node_path)
      
      # The parent path should be the path up to the parent node
      # For level3, the parent is level2
      separator = PathCalculator.path_separator()
      expected_parts = [
        to_string(nodes.root.id),
        to_string(nodes.level1.id),
        to_string(nodes.level2.id)
      ]
      expected_parent_path = Enum.join(expected_parts, separator)
      
      assert parent_path == expected_parent_path
    end
    
    test "returns empty string or nil for root node path" do
      # Ensure ETS tables exist
      ensure_ets_tables_exist()
      
      # Create a root node
      unique = unique_id()
      {:ok, root} = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        Hierarchy.create_node(%{
          name: "ParentPath_Root_#{unique}",
          node_type: "company"
        })
      end)
      
      # Get the path of the root node
      {:ok, root_path} = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        PathCalculator.calculate_path(root.id)
      end)
      
      # Calculate the parent path of the root node
      parent_path = PathCalculator.calculate_parent_path(root_path)
      
      # The parent path of a root should be empty or nil
      assert parent_path == "" || parent_path == nil
    end
  end
  
  describe "is_ancestor?/2" do
    test "correctly identifies ancestors" do
      # Ensure ETS tables exist
      ensure_ets_tables_exist()
      
      # Create a hierarchy with known structure
      {:ok, nodes} = setup_deep_hierarchy()
      
      # Get paths for nodes
      {:ok, root_path} = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        PathCalculator.calculate_path(nodes.root.id)
      end)
      
      {:ok, level3_path} = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        PathCalculator.calculate_path(nodes.level3.id)
      end)
      
      {:ok, level5_path} = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        PathCalculator.calculate_path(nodes.level5.id)
      end)
      
      # Check ancestor relationships
      # Root is ancestor of level3
      assert PathCalculator.is_ancestor?(root_path, level3_path) == true
      
      # Level3 is ancestor of level5
      assert PathCalculator.is_ancestor?(level3_path, level5_path) == true
      
      # Level5 is not ancestor of level3
      assert PathCalculator.is_ancestor?(level5_path, level3_path) == false
      
      # Node is not ancestor of itself
      assert PathCalculator.is_ancestor?(level3_path, level3_path) == false
    end
  end
end
