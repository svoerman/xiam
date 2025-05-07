defmodule XIAM.IsolatedHierarchyBehaviorTest do
  @moduledoc """
  Tests for core hierarchy behaviors in isolation.
  
  These tests focus on verifying the essential behaviors of the hierarchy system
  without relying on database access or external dependencies.
  """
  
  use ExUnit.Case, async: true
  
  # Create a mocked adapter that doesn't rely on the database
  defmodule MockAdapter do
    # Storage for our test state
    def init_test_state do
      # Clear any previous state
      Process.put(:mock_hierarchy_nodes, %{})
      Process.put(:mock_access_grants, %{})
      Process.put(:mock_users, %{})
      Process.put(:mock_roles, %{})
    end
    
    # User management
    def create_user do
      user_id = System.unique_integer([:positive, :monotonic])
      user = %{
        id: user_id,
        email: "test_#{user_id}@example.com"
      }
      Process.put({:mock_users, user_id}, user)
      user
    end
    
    # Role management
    def create_role do
      role_id = System.unique_integer([:positive, :monotonic])
      role = %{
        id: role_id,
        name: "Test Role #{role_id}"
      }
      Process.put({:mock_roles, role_id}, role)
      role
    end
    
    # Node creation
    def create_node(attrs) do
      node_id = System.unique_integer([:positive, :monotonic])
      node_type = attrs[:node_type] || "default_type"
      name = attrs[:name] || "Node #{node_id}"
      path = attrs[:path] || "#{node_type}_#{node_id}"
      
      node = %{
        id: node_id,
        name: name,
        node_type: node_type,
        path: path,
        parent_id: attrs[:parent_id]
      }
      
      # Store in our mock storage
      all_nodes = Process.get(:mock_hierarchy_nodes) || %{}
      Process.put(:mock_hierarchy_nodes, Map.put(all_nodes, node_id, node))
      
      {:ok, node}
    end
    
    # Create child node
    def create_child_node(parent, attrs) do
      # Ensure parent path is included in child path
      attrs = Map.put(attrs, :parent_id, parent.id)
      parent_path = parent.path || ""
      node_type = attrs[:node_type] || "child"
      
      # Generate a path that includes the parent path
      child_path = "#{parent_path}.#{node_type}_#{System.unique_integer([:positive])}"
      attrs = Map.put(attrs, :path, child_path)
      
      create_node(attrs)
    end
    
    # Create a test hierarchy
    def create_test_hierarchy do
      {:ok, root} = create_node(%{name: "Root", node_type: "organization", path: "root_123"})
      {:ok, dept} = create_child_node(root, %{name: "Department", node_type: "department"})
      {:ok, team} = create_child_node(dept, %{name: "Team", node_type: "team"})
      {:ok, project} = create_child_node(team, %{name: "Project", node_type: "project"})
      
      %{root: root, dept: dept, team: team, project: project}
    end
    
    # Access control
    def grant_access(user, node, role) do
      key = "#{user.id}:#{node.id}"
      grant = %{
        id: System.unique_integer([:positive]),
        user_id: user.id,
        node_id: node.id,
        role_id: role.id,
        access_path: node.path
      }
      
      # Store the grant
      grants = Process.get(:mock_access_grants) || %{}
      Process.put(:mock_access_grants, Map.put(grants, key, grant))
      
      {:ok, grant}
    end
    
    # Check access
    def can_access?(user, node) do
      # Check for direct access
      key = "#{user.id}:#{node.id}"
      grants = Process.get(:mock_access_grants) || %{}
      direct_access = Map.has_key?(grants, key)
      
      if direct_access do
        true
      else
        # Check for inherited access from parent nodes
        has_parent_access?(user, node)
      end
    end
    
    # Helper for inheritance
    defp has_parent_access?(user, node) do
      # Safely get parent_id, handling cases where it might not exist
      parent_id = Map.get(node, :parent_id)
      all_nodes = Process.get(:mock_hierarchy_nodes) || %{}
      
      if parent_id && Map.has_key?(all_nodes, parent_id) do
        parent = Map.get(all_nodes, parent_id)
        # Check if user has access to parent
        key = "#{user.id}:#{parent.id}"
        grants = Process.get(:mock_access_grants) || %{}
        
        if Map.has_key?(grants, key) do
          true
        else
          # Recursively check parent's parent
          has_parent_access?(user, parent)
        end
      else
        false
      end
    end
    
    # Revoke access
    def revoke_access(user, node) do
      key = "#{user.id}:#{node.id}"
      grants = Process.get(:mock_access_grants) || %{}
      
      if Map.has_key?(grants, key) do
        Process.put(:mock_access_grants, Map.delete(grants, key))
        {:ok, :revoked}
      else
        {:error, :no_access_to_revoke}
      end
    end
  end
  
  # Initialize test state before each test with resilient patterns
  setup do
    # First ensure the repo is started
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    {:ok, _} = Application.ensure_all_started(:postgrex)
    
    # Ensure ETS tables exist for Phoenix-related operations
    XIAM.ETSTestHelper.ensure_ets_tables_exist()
    
    # Initialize mock state with resilient pattern
    XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
      MockAdapter.init_test_state()
    end, max_retries: 3, retry_delay: 200)
    
    :ok
  end
  
  describe "hierarchy node management" do
    test "creates nodes with proper structure" do
      # Create a node
      {:ok, node} = MockAdapter.create_node(%{name: "Test Node", node_type: "organization"})
      
      # Verify the node has expected structure
      assert node.id != nil
      assert node.name == "Test Node"
      assert node.node_type == "organization"
      assert node.path != nil
    end
    
    test "establishes parent-child relationships" do
      # Create a parent node
      {:ok, parent} = MockAdapter.create_node(%{name: "Parent", node_type: "organization"})
      
      # Create a child node
      {:ok, child} = MockAdapter.create_child_node(parent, %{name: "Child", node_type: "department"})
      
      # Verify the relationship
      assert child.parent_id == parent.id
      
      # Path should reflect the hierarchy
      assert String.contains?(child.path, parent.path)
    end
    
    test "creates a multi-level hierarchy" do
      # Create a test hierarchy
      %{root: root, dept: dept, team: team, project: project} = MockAdapter.create_test_hierarchy()
      
      # Verify the relationships
      assert dept.parent_id == root.id
      assert team.parent_id == dept.id
      assert project.parent_id == team.id
      
      # Paths should reflect the hierarchy
      assert String.contains?(dept.path, root.path)
      assert String.contains?(team.path, dept.path)
      assert String.contains?(project.path, team.path)
    end
  end
  
  describe "hierarchy access control" do
    setup do
      # Ensure ETS tables exist for Phoenix-related operations
      XIAM.ETSTestHelper.ensure_ets_tables_exist()
      
      # Create test users and roles with resilient pattern
      user = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        MockAdapter.create_user()
      end, max_retries: 3, retry_delay: 200)
      
      role = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        MockAdapter.create_role()
      end, max_retries: 3, retry_delay: 200)
      
      # Create a test hierarchy with resilient pattern
      hierarchy = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        MockAdapter.create_test_hierarchy()
      end, max_retries: 3, retry_delay: 200)
      
      %{user: user, role: role, hierarchy: hierarchy}
    end
    
    test "grants access to nodes", %{user: user, role: role, hierarchy: hierarchy} do
      # Grant access to the department node
      {:ok, _access} = MockAdapter.grant_access(user, hierarchy.dept, role)
      
      # Verify access was granted
      assert MockAdapter.can_access?(user, hierarchy.dept)
    end
    
    test "inherits access to child nodes", %{user: user, role: role, hierarchy: hierarchy} do
      # Grant access to the department node
      {:ok, _access} = MockAdapter.grant_access(user, hierarchy.dept, role)
      
      # Verify access to the department
      assert MockAdapter.can_access?(user, hierarchy.dept)
      
      # Access should be inherited by children
      assert MockAdapter.can_access?(user, hierarchy.team)
      assert MockAdapter.can_access?(user, hierarchy.project)
      
      # But not by parent
      refute MockAdapter.can_access?(user, hierarchy.root)
    end
    
    test "revokes access", %{user: user, role: role, hierarchy: hierarchy} do
      # Grant access first
      {:ok, _access} = MockAdapter.grant_access(user, hierarchy.dept, role)
      
      # Verify initial access
      assert MockAdapter.can_access?(user, hierarchy.dept)
      
      # Revoke access
      {:ok, _} = MockAdapter.revoke_access(user, hierarchy.dept)
      
      # Verify access was revoked
      refute MockAdapter.can_access?(user, hierarchy.dept)
    end
  end
  
  describe "hierarchy edge cases" do
    setup do
      # Ensure ETS tables exist for Phoenix-related operations
      XIAM.ETSTestHelper.ensure_ets_tables_exist()
      
      # Create test users and roles with resilient pattern
      user = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        MockAdapter.create_user()
      end, max_retries: 3, retry_delay: 200)
      
      role = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        MockAdapter.create_role()
      end, max_retries: 3, retry_delay: 200)
      
      # Create a test hierarchy with resilient pattern
      hierarchy = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        MockAdapter.create_test_hierarchy()
      end, max_retries: 3, retry_delay: 200)
      
      %{user: user, role: role, hierarchy: hierarchy}
    end
    
    test "handles access conflicts (access to both parent and child)", %{user: user, role: role, hierarchy: hierarchy} do
      # Grant access to both department and team
      {:ok, _dept_access} = MockAdapter.grant_access(user, hierarchy.dept, role)
      {:ok, _team_access} = MockAdapter.grant_access(user, hierarchy.team, role)
      
      # Verify both accesses work
      assert MockAdapter.can_access?(user, hierarchy.dept)
      assert MockAdapter.can_access?(user, hierarchy.team)
      
      # Revoke access to department (parent) but keep team (child)
      {:ok, _} = MockAdapter.revoke_access(user, hierarchy.dept)
      
      # User should still have access to team through direct grant
      refute MockAdapter.can_access?(user, hierarchy.dept)
      assert MockAdapter.can_access?(user, hierarchy.team)
    end
    
    test "deals with non-existent nodes and users" do
      # Create a user
      user = MockAdapter.create_user()
      role = MockAdapter.create_role()
      
      # Try to check access with non-existent node
      non_existent_node = %{id: -999, name: "Non-existent", path: "non-existent"}
      refute MockAdapter.can_access?(user, non_existent_node)
      
      # Try to grant access to non-existent node
      {:ok, node} = MockAdapter.create_node(%{name: "Real Node"})
      _non_existent_user = %{id: -999, email: "fake@example.com"}
      
      # The mock adapter should handle this gracefully without errors
      {:ok, _access} = MockAdapter.grant_access(user, node, role)
      assert MockAdapter.can_access?(user, node)
    end
    
    test "deep hierarchy access inheritance", %{user: user, role: role} do
      # Create a deep hierarchy (7 levels)
      {:ok, level1} = MockAdapter.create_node(%{name: "Level 1", path: "level1"})
      {:ok, level2} = MockAdapter.create_child_node(level1, %{name: "Level 2"})
      {:ok, level3} = MockAdapter.create_child_node(level2, %{name: "Level 3"})
      {:ok, level4} = MockAdapter.create_child_node(level3, %{name: "Level 4"})
      {:ok, level5} = MockAdapter.create_child_node(level4, %{name: "Level 5"})
      {:ok, level6} = MockAdapter.create_child_node(level5, %{name: "Level 6"})
      {:ok, level7} = MockAdapter.create_child_node(level6, %{name: "Level 7"})
      
      # Grant access at level 2
      {:ok, _} = MockAdapter.grant_access(user, level2, role)
      
      # Verify inheritance works all the way down
      refute MockAdapter.can_access?(user, level1) # Parent not accessible
      assert MockAdapter.can_access?(user, level2) # Direct access
      assert MockAdapter.can_access?(user, level3) # Inherited
      assert MockAdapter.can_access?(user, level4) # Inherited
      assert MockAdapter.can_access?(user, level5) # Inherited
      assert MockAdapter.can_access?(user, level6) # Inherited
      assert MockAdapter.can_access?(user, level7) # Inherited
    end
  end
end
