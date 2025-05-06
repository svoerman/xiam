defmodule XIAM.Hierarchy.AccessControlMockTest do
  @moduledoc """
  Tests for access control behaviors using the mock adapter.
  
  These tests verify the same functionality as AccessControlTest but use
  an in-memory mock adapter that doesn't rely on the database.
  """
  
  use XIAM.DataCase, async: true
  
  alias XIAM.HierarchyMockAdapter, as: MockHierarchy
  
  setup do
    # Create a test user and role
    user_id = System.unique_integer([:positive, :monotonic])
    role_id = System.unique_integer([:positive, :monotonic])
    
    user = %{id: user_id, email: "test_#{user_id}@example.com"}
    role = %{id: role_id, name: "Editor #{role_id}"}
    
    # Create a test hierarchy using the mock adapter
    {:ok, root} = MockHierarchy.create_test_node(%{
      name: "Root",
      node_type: "organization",
      path: "root"
    })
    
    {:ok, dept} = MockHierarchy.create_test_node(%{
      name: "Department",
      node_type: "department",
      parent_id: root.id,
      path: "root.department"
    })
    
    {:ok, team} = MockHierarchy.create_test_node(%{
      name: "Team",
      node_type: "team",
      parent_id: dept.id,
      path: "root.department.team"
    })
    
    {:ok, project} = MockHierarchy.create_test_node(%{
      name: "Project",
      node_type: "project",
      parent_id: team.id,
      path: "root.department.team.project"
    })
    
    %{user: user, role: role, root: root, dept: dept, team: team, project: project}
  end
  
  describe "granting access" do
    test "grants access to a node", %{user: user, role: role, dept: dept} do
      # Grant access
      assert {:ok, access} = MockHierarchy.grant_access(user.id, dept.id, role.id)
      
      # Verify access grant structure
      assert access.user_id == user.id
      assert access.role_id == role.id
      assert access.access_path == dept.path
      
      # Verify access was granted
      assert MockHierarchy.can_access?(user.id, dept.id)
    end
    
    test "prevents duplicate access grants", %{user: user, role: role, dept: dept} do
      # Grant access first time
      assert {:ok, access1} = MockHierarchy.grant_access(user.id, dept.id, role.id)
      
      # Attempt to grant same access again (should update the existing grant)
      assert {:ok, access2} = MockHierarchy.grant_access(user.id, dept.id, role.id)
      
      # Should be the same access record
      assert access1.id == access2.id
    end
  end
  
  describe "checking access" do
    test "checks direct access", %{user: user, role: role, dept: dept} do
      # Grant access to department
      {:ok, _} = MockHierarchy.grant_access(user.id, dept.id, role.id)
      
      # Check access
      assert MockHierarchy.can_access?(user.id, dept.id)
    end
    
    test "inherits access to child nodes", %{user: user, role: role, dept: dept, team: team, project: project} do
      # Grant access to the department node
      {:ok, _access} = MockHierarchy.grant_access(user.id, dept.id, role.id)
      
      # Verify access to the department
      assert MockHierarchy.can_access?(user.id, dept.id)
      
      # Access should be inherited by children
      assert MockHierarchy.can_access?(user.id, team.id)
      assert MockHierarchy.can_access?(user.id, project.id)
    end
    
    test "does not grant access to parent nodes", %{user: user, role: role, dept: dept, root: root} do
      # Grant access to department
      {:ok, _} = MockHierarchy.grant_access(user.id, dept.id, role.id)
      
      # Should have access to department
      assert MockHierarchy.can_access?(user.id, dept.id)
      
      # Should not have access to parent (root)
      refute MockHierarchy.can_access?(user.id, root.id)
    end
  end
  
  describe "revoking access" do
    test "revokes access", %{user: user, role: role, dept: dept} do
      # Grant access first
      {:ok, access} = MockHierarchy.grant_access(user.id, dept.id, role.id)
      
      # Verify initial access
      assert MockHierarchy.can_access?(user.id, dept.id)
      
      # Revoke access
      assert {:ok, _} = MockHierarchy.revoke_access(access.id)
      
      # Verify access is revoked
      refute MockHierarchy.can_access?(user.id, dept.id)
    end
    
    test "revokes access to child nodes", %{user: user, role: role, dept: dept, team: team, project: project} do
      # Grant access to department
      {:ok, access} = MockHierarchy.grant_access(user.id, dept.id, role.id)
      
      # Verify access to department and child nodes
      assert MockHierarchy.can_access?(user.id, dept.id)
      assert MockHierarchy.can_access?(user.id, team.id)
      assert MockHierarchy.can_access?(user.id, project.id)
      
      # Revoke access
      assert {:ok, _} = MockHierarchy.revoke_access(access.id)
      
      # Should no longer have access to department or any child nodes
      refute MockHierarchy.can_access?(user.id, dept.id)
      refute MockHierarchy.can_access?(user.id, team.id)
      refute MockHierarchy.can_access?(user.id, project.id)
    end
    
    test "revokes specific user-node access", %{user: user, role: role, dept: dept} do
      # Grant access first
      {:ok, _} = MockHierarchy.grant_access(user.id, dept.id, role.id)
      
      # Verify initial access
      assert MockHierarchy.can_access?(user.id, dept.id)
      
      # Revoke access using user_id and node_id
      assert {:ok, _} = MockHierarchy.revoke_user_access(user.id, dept.id)
      
      # Verify access is revoked
      refute MockHierarchy.can_access?(user.id, dept.id)
    end
  end
end
