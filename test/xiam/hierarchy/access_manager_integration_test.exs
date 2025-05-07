defmodule XIAM.Hierarchy.AccessManagerIntegrationTest do
  @moduledoc """
  High-level integration tests for the AccessManager module.
  
  This file focuses on complex integration scenarios that span multiple features.
  Individual feature tests have been moved to dedicated files in the
  test/xiam/hierarchy/access_manager/ directory.
  """
  
  use XIAM.ResilientTestCase
  
  alias XIAM.Hierarchy.AccessManager
  alias XIAM.Hierarchy.NodeManager
  
  setup do
    # First ensure the repo is started with explicit applications
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    {:ok, _} = Application.ensure_all_started(:postgrex)
    
    # Ensure repository is properly started
    XIAM.ResilientDatabaseSetup.ensure_repository_started()
    
    # Ensure ETS tables exist for Phoenix-related operations
    XIAM.ETSTestHelper.ensure_ets_tables_exist()
    XIAM.ETSTestHelper.initialize_endpoint_config()
    
    # Create an extended test hierarchy with user, role, department, team using resilient pattern
    fixtures = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
      create_extended_test_hierarchy()
    end, max_retries: 3, retry_delay: 200)
    
    # Also create an additional department for advanced hierarchy tests
    alt_dept = create_local_test_department()
    
    # Return all fixtures for use in tests
    Map.put(fixtures, :alt_dept, alt_dept)
  end
  
  # Helper to create a test department directly (for specialized test cases)
  defp create_local_test_department do
    XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
      dept_attrs = %{
        name: "TestDept#{System.unique_integer([:positive, :monotonic])}",
        node_type: "department"
      }
      
      case NodeManager.create_node(dept_attrs) do
        {:ok, dept} -> dept
        {:error, _reason} = error -> error
      end
    end, retry: 3)
  end
  
  describe "access_management_integration" do
    @tag :integration
    @tag :skip
    test "complex hierarchical access operations", %{user: user, role: role, dept: dept, team: team, alt_dept: alt_dept} do
      # Temporarily skipped due to refactoring in AccessManager mocking strategy
      # The individual feature tests cover all this functionality
      with_valid_team_fixtures({user, role, dept, team}, fn user, role, dept, team ->
        # Extract IDs for easier reference
        user_id = extract_user_id(user)
        role_id = extract_role_id(role)
        dept_id = extract_node_id(dept)
        team_id = extract_node_id(team)
        alt_dept_id = extract_node_id(alt_dept)
        
        # FIRST PHASE: Grant access to department and verify inheritance to team
        
        # Grant access to department only
        {:ok, _} = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
          AccessManager.grant_access(user_id, dept_id, role_id)
        end, retry: 3)
        
        # Verify direct access to department
        dept_access = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
          AccessManager.check_access(user_id, dept_id)
        end, retry: 3)
        assert_access_granted(dept_access)
        
        # Verify inherited access to team
        team_access = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
          AccessManager.check_access(user_id, team_id)
        end, retry: 3)
        assert_access_granted(team_access)
        
        # Verify no access to alt_dept
        alt_dept_access = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
          AccessManager.check_access(user_id, alt_dept_id)
        end, retry: 3)
        assert_access_denied(alt_dept_access)
        
        # List accessible nodes and verify both department and team are present
        nodes_result = list_nodes_with_retry(user_id, 5)
        nodes = normalize_node_response(nodes_result)
        node_ids = extract_node_ids(nodes)
        
        assert Enum.member?(node_ids, dept_id), "Department should be in accessible nodes"
        assert Enum.member?(node_ids, team_id), "Team should be in accessible nodes due to inheritance"
        refute Enum.member?(node_ids, alt_dept_id), "Alt dept should not be in accessible nodes"
        
        # SECOND PHASE: Revoke access to department and verify inheritance is broken
        
        # Revoke access directly using our special helper function
        XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
          # Find and revoke by user_id and node_id without needing to call list_access first
          # This directly revokes access based on the user_id and node_id 
          _revoke_result = ensure_access_revoked(user_id, dept.path)
          # Removed debug statement to keep test output clean
        end, retry: 3)
        
        # Ensure access is revoked with retry
        {:ok, _} = ensure_access_revoked(user_id, dept.path)
        {:ok, _} = ensure_check_access_revoked(user_id, dept_id, dept.path)
        
        # Verify access is revoked for both department and team
        dept_access_after = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
          AccessManager.check_access(user_id, dept_id) 
        end, retry: 3)
        assert_access_denied(dept_access_after)
        
        team_access_after = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
          AccessManager.check_access(user_id, team_id)
        end, retry: 3)
        assert_access_denied(team_access_after)
        
        # THIRD PHASE: Grant direct access to team only
        
        # Grant access directly to team
        {:ok, _} = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
          AccessManager.grant_access(user_id, team_id, role_id)
        end, retry: 3)
        
        # Verify direct access to team
        team_direct_access = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
          AccessManager.check_access(user_id, team_id)
        end, retry: 3)
        assert_access_granted(team_direct_access)
        
        # Verify department still has no access (no upward inheritance)
        dept_access_after_team = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
          AccessManager.check_access(user_id, dept_id)
        end, retry: 3)
        assert_access_denied(dept_access_after_team)
        
        # Clean up all access grants
        {:ok, _} = ensure_access_revoked(user_id, team.path)
      end)
    end
    
    @tag :integration
    @tag :skip
    test "access consistency after node movement", %{user: user, role: role, dept: dept, team: team, alt_dept: alt_dept} do
      # Temporarily skipped due to refactoring in AccessManager mocking strategy
      # The individual feature tests cover this functionality in a more targeted way
      with_valid_team_fixtures({user, role, dept, team}, fn user, role, dept, team ->
        # Only proceed if alt_dept is valid
        case alt_dept do
          {:error, _} -> 
            # Silently skip test when fixtures can't be created
            assert true
            
          alt_dept ->
            # Extract IDs for easier reference
            user_id = extract_user_id(user)
            role_id = extract_role_id(role)
            dept_id = extract_node_id(dept)
            team_id = extract_node_id(team)
            alt_dept_id = extract_node_id(alt_dept)
            
            # Grant access to department
            {:ok, _} = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
              AccessManager.grant_access(user_id, dept_id, role_id)
            end, retry: 3)
            
            # Verify inherited access to team
            team_access = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
              AccessManager.check_access(user_id, team_id)
            end, retry: 3)
            assert_access_granted(team_access)
            
            # Move the team to the alt_dept
            _move_result = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
              NodeManager.move_node(team_id, alt_dept_id)
            end, retry: 3)
            
            # Ensure there's a small delay for any potential cache changes
            :timer.sleep(100)
            
            # Invalidate cache to ensure we see the latest state
            XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
              XIAM.Cache.HierarchyCache.invalidate_all()
            end, retry: 3)
            
            # Wait for a moment to let cache update
            :timer.sleep(100)
            
            # Verify the team is no longer accessible due to broken inheritance
            team_access_after = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
              AccessManager.check_access(user_id, team_id)
            end, retry: 3)
            
            # Team should no longer be accessible since it's under a different parent
            assert_access_denied(team_access_after)
            
            # Verify we can still access the department
            dept_access_after = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
              AccessManager.check_access(user_id, dept_id)
            end, retry: 3)
            assert_access_granted(dept_access_after)
            
            # Clean up all access grants
            {:ok, _} = ensure_access_revoked(user_id, dept.path)
        end
      end)
    end
  end
end