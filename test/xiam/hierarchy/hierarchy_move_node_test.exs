defmodule XIAM.HierarchyMoveNodeTest do
  @moduledoc """
  Tests for the node movement functionality in the hierarchy system.
  
  These tests focus on verifying that node movement operations maintain
  hierarchical integrity and prevent invalid operations like circular references.
  """
  
  use XIAM.DataCase, async: true
  
  alias XIAM.HierarchyMockAdapter, as: MockHierarchy
  
  describe "move_node" do
    setup do
      # First ensure the repo is started with explicit applications
      {:ok, _} = Application.ensure_all_started(:ecto_sql)
      {:ok, _} = Application.ensure_all_started(:postgrex)
      
      # Ensure repository is properly started
      XIAM.ResilientDatabaseSetup.ensure_repository_started()
      
      # Ensure ETS tables exist for Phoenix-related operations
      XIAM.ETSTestHelper.ensure_ets_tables_exist()
      
      # Add timestamp to names to ensure uniqueness
      timestamp = System.system_time(:millisecond)
      random_suffix = :rand.uniform(100_000)
      unique_id = "#{timestamp}_#{random_suffix}"
      
      # Create a test hierarchy with resilient patterns
      root = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        {:ok, node} = MockHierarchy.create_test_node(%{
          name: "Root_#{unique_id}",
          node_type: "organization",
          path: "root_#{unique_id}"
        })
        node
      end, max_retries: 3, retry_delay: 200)
      
      dept = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        {:ok, node} = MockHierarchy.create_test_node(%{
          name: "Department_#{unique_id}",
          node_type: "department",
          parent_id: root.id,
          path: "#{root.path}.Department_#{unique_id}"
        })
        node
      end, max_retries: 3, retry_delay: 200)
      
      team = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        {:ok, node} = MockHierarchy.create_test_node(%{
          name: "Team_#{unique_id}",
          node_type: "team",
          parent_id: dept.id,
          path: "#{dept.path}.Team_#{unique_id}"
        })
        node
      end, max_retries: 3, retry_delay: 200)
      
      project = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        {:ok, node} = MockHierarchy.create_test_node(%{
          name: "Project_#{unique_id}",
          node_type: "project",
          parent_id: team.id,
          path: "#{team.path}.Project_#{unique_id}"
        })
        node
      end, max_retries: 3, retry_delay: 200)
      
      %{root: root, dept: dept, team: team, project: project}
    end
    
    test "successfully moves a node to a new parent", %{root: root, dept: dept, team: team} do
      # Move team from department to directly under root
      assert {:ok, moved_team} = MockHierarchy.move_node(team.id, root.id)
      
      # Verify updated parent reference
      assert moved_team.parent_id == root.id
      
      # Verify path structure rather than exact path value
      # The path should now contain the root path but not the department path
      assert String.contains?(moved_team.path, root.path)
      refute String.contains?(moved_team.path, dept.path)
    end
    
    test "updates paths of descendant nodes after move", %{root: root, dept: dept, team: team, project: project} do
      # Move team from department to directly under root
      assert {:ok, moved_team} = MockHierarchy.move_node(team.id, root.id)
      
      # Get the updated project node from process dictionary
      updated_project = Process.get({:test_node_data, project.id})
      
      # Verify descendant nodes had paths updated
      # Verify the path structure rather than exact values
      # The project path should contain the moved team path, which should contain the root path
      assert String.contains?(updated_project.path, moved_team.path)
      assert String.contains?(updated_project.path, root.path)
      # But should not contain the dept path anymore
      refute String.contains?(updated_project.path, dept.path)
    end
    
    test "prevents circular references by rejecting moves that would create cycles", %{dept: dept, team: team, root: root} do
      # Attempt to move department under team (which is a child of department)
      # This would create a circular reference: dept -> team -> dept
      assert {:error, :circular_reference} = MockHierarchy.move_node(dept.id, team.id)
      
      # Verify department's path structure is maintained
      unchanged_dept = Process.get({:test_node_data, dept.id})
      # Path should still contain the department name
      assert String.contains?(unchanged_dept.path, "Department")
      # And should still be related to root
      assert String.contains?(unchanged_dept.path, root.path)
    end
    
    test "prevents self-reference by rejecting moves to self", %{dept: dept, root: root} do
      # Attempt to move department under itself
      assert {:error, :circular_reference} = MockHierarchy.move_node(dept.id, dept.id)
      
      # Verify department's path structure is maintained
      unchanged_dept = Process.get({:test_node_data, dept.id})
      # Path should still contain the department name
      assert String.contains?(unchanged_dept.path, "Department")
      # And should still be related to root
      assert String.contains?(unchanged_dept.path, root.path)
    end
  end
end
