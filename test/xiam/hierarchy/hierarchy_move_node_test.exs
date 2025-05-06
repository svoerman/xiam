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
      # Create a test hierarchy
      {:ok, root} = MockHierarchy.create_test_node(%{
        name: "Root",
        node_type: "organization",
        path: "root"
      })
      
      {:ok, dept} = MockHierarchy.create_test_node(%{
        name: "Department",
        node_type: "department",
        parent_id: root.id,
        path: "root.Department"
      })
      
      {:ok, team} = MockHierarchy.create_test_node(%{
        name: "Team",
        node_type: "team",
        parent_id: dept.id,
        path: "root.Department.Team"
      })
      
      {:ok, project} = MockHierarchy.create_test_node(%{
        name: "Project",
        node_type: "project",
        parent_id: team.id,
        path: "root.Department.Team.Project"
      })
      
      %{root: root, dept: dept, team: team, project: project}
    end
    
    test "successfully moves a node to a new parent", %{root: root, dept: _dept, team: team} do
      # Move team from department to directly under root
      assert {:ok, moved_team} = MockHierarchy.move_node(team.id, root.id)
      
      # Verify updated parent reference
      assert moved_team.parent_id == root.id
      
      # Verify path was updated correctly
      assert moved_team.path == "root.Team"
    end
    
    test "updates paths of descendant nodes after move", %{root: root, dept: _dept, team: team, project: project} do
      # Move team from department to directly under root
      assert {:ok, _} = MockHierarchy.move_node(team.id, root.id)
      
      # Get the updated project node (team's child)
      updated_project = Process.get({:test_node_data, project.id})
      
      # Verify project's path was updated to reflect its parent's new path
      assert updated_project.path == "root.Team.Project"
    end
    
    test "prevents circular references by rejecting moves that would create cycles", %{dept: dept, team: team} do
      # Attempt to move department under team (which is a child of department)
      # This would create a circular reference: dept -> team -> dept
      assert {:error, :circular_reference} = MockHierarchy.move_node(dept.id, team.id)
      
      # Verify department's original path is unchanged
      unchanged_dept = Process.get({:test_node_data, dept.id})
      assert unchanged_dept.path == "root.Department"
    end
    
    test "prevents self-reference by rejecting moves to self", %{dept: dept} do
      # Attempt to move department under itself
      assert {:error, :circular_reference} = MockHierarchy.move_node(dept.id, dept.id)
      
      # Verify department's original path is unchanged
      unchanged_dept = Process.get({:test_node_data, dept.id})
      assert unchanged_dept.path == "root.Department"
    end
  end
end
