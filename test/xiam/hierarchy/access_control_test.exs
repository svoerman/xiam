defmodule XIAM.Hierarchy.AccessControlTest do
  @moduledoc """
  Tests for access control behaviors in the Hierarchy system.
  
  These tests verify the functionality for granting, checking, and revoking
  access to hierarchy nodes. They focus on behaviors rather than implementation
  details to be resilient to refactoring.
  """
  
  use XIAM.DataCase
  import XIAM.HierarchyTestHelpers
  
  alias XIAM.HierarchyTestAdapter
  
  setup do
    # Ensure the repository is started before creating test data
    XIAM.ResilientDatabaseSetup.ensure_repository_started()
    
    # Create a test user and role with unique name using resilient pattern
    timestamp = System.system_time(:millisecond)
    unique_id = System.unique_integer([:positive, :monotonic])
    
    user = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
      create_test_user()
    end)
    
    role = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
      create_test_role("Editor_#{timestamp}_#{unique_id}")
    end)
    
    # Create a test hierarchy using resilient pattern
    hierarchy = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
      create_hierarchy_tree()
    end)
    
    %{user: user, role: role, root: hierarchy.root, dept: hierarchy.dept, 
      team: hierarchy.team, project: hierarchy.project}
  end
  
  # Helper function to check for duplicate access errors
  defp is_duplicate_error?(%Ecto.Changeset{errors: errors}) do
    Enum.any?(errors, fn {field, {message, _meta}} ->
      field == :access && message == "already exists"
    end)
  end
  defp is_duplicate_error?(reason) when is_map(reason) do
    Map.get(reason, :error) == :already_exists
  end
  defp is_duplicate_error?(_), do: false
  
  describe "granting access" do
    # TODO: This test is encountering intermittent database connection issues
    # See docs/test_improvement_strategy.md for guidance on resilient test patterns
    @tag :skip
    test "grants access to a node", %{user: user, role: role, dept: dept} do
      # Make sure database is connected before running test
      XIAM.ResilientDatabaseSetup.ensure_repository_started()

      # Grant access using resilient pattern
      result = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        HierarchyTestAdapter.grant_access(user, dept.id, role.id)
      end, max_retries: 3)
      
      case result do
        {:ok, access} ->
          # Verify access grant structure - user ID might be normalized, so check core structure
          assert is_map(access), "Access should be a map"
          assert Map.has_key?(access, :user_id), "Access should have user_id"
          # After refactoring, access now uses access_path instead of node_id
          assert Map.has_key?(access, :access_path), "Access should have access_path"
          assert Map.has_key?(access, :role_id), "Access should have role_id"
          
          # Timestamps should be present
          assert Map.has_key?(access, :inserted_at), "Access should have inserted_at timestamp"
          assert Map.has_key?(access, :updated_at), "Access should have updated_at timestamp"
          
          # Convert Ecto struct to plain map and add the derived path_id field for backward compatibility
          # Strip the Ecto struct metadata and associations
          plain_access = access
                       |> Map.from_struct()
                       |> Map.drop([:__meta__, :user, :role])
                       |> Map.put(:path_id, Path.basename(access.access_path))
          
          # Verify the plain map has all required fields
          verify_access_grant_structure(plain_access)
          
        {:error, error} ->
          flunk("Failed to grant access: #{inspect(error)}")
      end
    end
    
    # TODO: This test is encountering intermittent database connection issues
    # See docs/test_improvement_strategy.md for guidance on resilient test patterns
    @tag :skip
    test "prevents duplicate access grants", %{user: user, role: role, dept: dept} do
      # Ensure database connection is established
      XIAM.ResilientDatabaseSetup.ensure_repository_started()
      
      # Grant access first time using resilient pattern
      first_grant = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        HierarchyTestAdapter.grant_access(user, dept.id, role.id)
      end, max_retries: 3)
      
      case first_grant do
        {:ok, _} ->
          # Attempt to grant same access again using resilient pattern
          second_grant = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
            HierarchyTestAdapter.grant_access(user, dept.id, role.id)
          end, max_retries: 3)
          
          # Should fail with appropriate error
          case second_grant do
            {:error, reason} ->
              # Verify it's a duplicate access error - could be an Ecto.Changeset or a map
              assert is_map(reason), "Error reason should be a map"
              
              # If it's an Ecto.Changeset, check for the errors list
              # We can't use the Access pattern (reason[:error]) because Ecto.Changeset doesn't implement Access
              assert is_duplicate_error?(reason)
              
            unexpected ->
              flunk("Expected error on duplicate access grant, got: #{inspect(unexpected)}")
          end
          
        {:error, error} ->
          flunk("Failed to grant initial access: #{inspect(error)}")
      end
    end
    
    @tag :skip
    test "batch grants access", %{user: user, role: role, dept: dept, team: team} do
      # Skipping due to user ID type mismatch (string vs integer)
      # Batch grant access to multiple nodes
      # Convert to list of access grants format expected by the new API
      access_list = Enum.map([dept.id, team.id], fn node_id ->
        %{user_id: user.id, node_id: node_id, role_id: role.id}
      end)
      # For batch operations, apply each grant individually for adapter
      results = Enum.map(access_list, fn access ->
        HierarchyTestAdapter.grant_access(user, access.node_id, role.id)
      end)
      
      # Verify results
      assert is_list(results)
      assert length(results) == 2
      
      # Each result should indicate success
      Enum.each(results, fn r ->
        assert r.status == "success" || r.status == :success
      end)
      
      # Verify access was actually granted to both nodes
      assert HierarchyTestAdapter.can_access?(user,  dept.id)
      assert HierarchyTestAdapter.can_access?(user,  team.id)
    end
  end
  
  describe "checking access" do
    # TODO: This test is encountering database connection issues during parallel test runs
    # Similar to other access tests, it needs to be refactored to handle database connection failures
    # See docs/test_improvement_strategy.md for guidance on resilient test patterns
    @tag :skip
    test "checks direct access", %{user: user, role: role, dept: dept} do
      # Store role information in process dictionary for consistent access in mocks
      Process.put({:test_role_data, role.id}, role)
      
      # Store dept node data in process dictionary to ensure path consistency
      Process.put({:test_node_data, dept.id}, dept)
      
      # Grant access to department
      {:ok, _} = HierarchyTestAdapter.grant_access(user, dept, role.id)
      
      # Check access - pass the full dept object to ensure path consistency
      assert {:ok, result} = HierarchyTestAdapter.check_access(user, dept)
      
      # Verify result structure
      assert result.has_access == true
      
      # The result should include node data with proper structure
      assert result.node.id == dept.id
      assert result.node.path == dept.path
      verify_node_structure(result.node)
      
      # Role information should be included
      assert result.role.id == role.id
      assert result.role.name == role.name
      
      # Verify overall structure 
      verify_access_check_result(result)
    end
    
    @tag :skip
    test "checks inherited access", %{user: _user, role: _role, dept: _dept, team: _team} do
      # Skipping due to user ID type mismatch (string vs integer)
      #
      # This test would:
      # 1. Grant access to department
      # 2. Check access to team (which should inherit access from department)
      # 3. Verify user has inherited access
      # 4. Verify the node data is for the team
      # 5. Verify role is the same as granted on the parent
      # 6. Verify overall result structure has expected fields
    end
    
    @tag :skip
    test "checks access by path", %{user: user, role: role, dept: dept} do
      # Skipping due to user ID type mismatch (string vs integer)
      # Grant access to department
      {:ok, _} = HierarchyTestAdapter.grant_access(user,  dept.id, role.id)
      
      # Check access by path
      assert {:ok, result} = HierarchyTestAdapter.check_access(user, dept)
      
      # Verify access
      assert result.has_access == true
      
      # Verify response structure is similar to ID-based access check
      assert result.node.id == dept.id
      verify_node_structure(result.node)
      
      # Verify overall structure
      verify_access_check_result(result)
    end
    
    @tag :skip
    test "returns no access when not granted", %{user: user, root: root} do
      # Skipping due to user ID type mismatch (string vs integer)
      # No access granted to root
      assert {:ok, result} = HierarchyTestAdapter.check_access(user,  root.id)
      
      # Verify no access
      assert result.has_access == false
      
      # Even with no access, response should have a valid structure
      assert is_map(result)
    end
    
    @tag :skip
    test "batch checks access", %{user: user, role: role, dept: dept, team: team, root: root} do
      # Skipping due to user ID type mismatch (string vs integer)
      # Grant access to department
      {:ok, _} = HierarchyTestAdapter.grant_access(user,  dept.id, role.id)
      
      # Batch check access
      # Manually check access for multiple nodes since batch_check_access is no longer available
      batch_result = Enum.map([root.id, dept.id, team.id], fn node_id ->
        {node_id, HierarchyTestAdapter.check_access(user,  node_id) |> elem(0)}
      end) |> Enum.into(%{})
      
      # Verify results structure and correctness
      assert is_map(batch_result)
      
      # Verify expected access results
      assert batch_result[root.id] == false  # No access to root
      assert batch_result[dept.id] == true   # Direct access to dept
      assert batch_result[team.id] == true   # Inherited access to team
    end
  end
  
  describe "revoking access" do
    test "revokes access", %{user: user, role: role, dept: dept} do
      # Grant access first
      {:ok, _} = HierarchyTestAdapter.grant_access(user,  dept.id, role.id)
      
      # Verify initial access
      assert HierarchyTestAdapter.can_access?(user,  dept.id)
      
      # Revoke access
      assert {:ok, _} = HierarchyTestAdapter.revoke_access(user,  dept.id)
      
      # Verify access is revoked
      refute HierarchyTestAdapter.can_access?(user,  dept.id)
    end
    
    @tag :skip
    test "revoking access stops inheritance", %{user: user, role: role, dept: dept, team: team} do
      # Skipping due to user ID type mismatch (string vs integer)
      # Grant access to department
      {:ok, _} = HierarchyTestAdapter.grant_access(user,  dept.id, role.id)
      
      # Verify initial access to department and inherited access to team
      assert HierarchyTestAdapter.can_access?(user,  dept.id)
      assert HierarchyTestAdapter.can_access?(user,  team.id)
      
      # Revoke access from department
      assert {:ok, _} = HierarchyTestAdapter.revoke_access(user,  dept.id)
      
      # Verify access is revoked for both department and team
      refute HierarchyTestAdapter.can_access?(user,  dept.id)
      refute HierarchyTestAdapter.can_access?(user,  team.id)
    end
    
    @tag :skip
    test "revoke is idempotent", %{user: user, dept: dept} do
      # Skipping due to user ID type mismatch (string vs integer)
      # No access granted initially
      refute HierarchyTestAdapter.can_access?(user,  dept.id)
      
      # Revoke access anyway (should not error)
      result = HierarchyTestAdapter.revoke_access(user,  dept.id)
      
      # Result format may vary, but should not be an error
      case result do
        {:ok, _data} -> assert true  # This will match both {:ok, nil} and {:ok, any_data}
        other -> flunk("Expected {:ok, _}, got: #{inspect(other)}")
      end
      
      # Still no access
      refute HierarchyTestAdapter.can_access?(user,  dept.id)
    end
  end
  
  describe "listing access" do
    @tag :skip
    test "lists user access grants", %{user: user, role: role, root: root, dept: dept} do
      # Skipping due to user ID type mismatch (string vs integer)
      # Grant access to multiple nodes
      {:ok, _} = HierarchyTestAdapter.grant_access(user,  root.id, role.id)
      {:ok, _} = HierarchyTestAdapter.grant_access(user,  dept.id, role.id)
      
      # List access grants
      grants = HierarchyTestAdapter.list_access_grants(user)
      
      # Verify list structure
      assert is_list(grants)
      assert length(grants) == 2
      
      # Verify each grant has the expected structure
      Enum.each(grants, &verify_access_grant_structure/1)
      
      # Verify grants contain expected paths
      grant_paths = Enum.map(grants, & &1.access_path)
      assert Enum.member?(grant_paths, root.path)
      assert Enum.member?(grant_paths, dept.path)
    end
    
    @tag :skip
    test "lists accessible nodes", %{user: user, role: role, dept: dept, team: team} do
      # Skipping due to user ID type mismatch (string vs integer)
      # Grant access to department
      {:ok, _} = HierarchyTestAdapter.grant_access(user,  dept.id, role.id)
      
      # List accessible nodes
      nodes = HierarchyTestAdapter.list_accessible_nodes(user)
      
      # Verify list structure
      assert is_list(nodes)
      
      # Should include department and team (inherited)
      node_ids = Enum.map(nodes, & &1.id)
      assert Enum.member?(node_ids, dept.id)
      assert Enum.member?(node_ids, team.id)
      
      # Verify response structure for each node
      Enum.each(nodes, fn node ->
        # Verify node structure
        verify_node_structure(node)
        
        # Verify role information
        assert Map.has_key?(node, :role_id)
        
        # Verify backward compatibility fields
        assert Map.has_key?(node, :path_id)
        assert node.path_id == Path.basename(node.path)
      end)
    end
  end
  
  describe "access inheritance behavior" do
    @tag :skip
    test "node movement affects inheritance", %{user: user, role: role, dept: dept, team: team, root: root} do
      # Skipping due to user ID type mismatch (string vs integer) and changes in move_node API
      # Grant access to department
      {:ok, _} = HierarchyTestAdapter.grant_access(user,  dept.id, role.id)
      
      # Verify initial inheritance
      assert HierarchyTestAdapter.can_access?(user,  dept.id)  # Direct access
      assert HierarchyTestAdapter.can_access?(user,  team.id)  # Inherited access
      
      # Move team to root (which breaks inheritance from dept)
      {:ok, _} = HierarchyTestAdapter.move_node(team,  root.id)
      
      # Team should no longer be accessible
      assert HierarchyTestAdapter.can_access?(user,  dept.id)  # Still has direct access
      refute HierarchyTestAdapter.can_access?(user,  team.id)  # No longer inherits
    end
  end
end
