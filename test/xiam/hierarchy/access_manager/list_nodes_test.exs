defmodule XIAM.Hierarchy.AccessManager.ListNodesTest do
  @moduledoc """
  Tests specific to listing accessible nodes functionality.
  """
  
  use XIAM.ResilientTestCase
  alias XIAM.Hierarchy.AccessManager
  
  describe "list_accessible_nodes/1" do
    setup do
      # First ensure the repo is started with explicit applications
      {:ok, _} = Application.ensure_all_started(:ecto_sql)
      {:ok, _} = Application.ensure_all_started(:postgrex)
      
      # Ensure repository is properly started
      XIAM.ResilientDatabaseSetup.ensure_repository_started()
      
      # Ensure ETS tables exist for Phoenix-related operations
      XIAM.ETSTestHelper.ensure_ets_tables_exist()
      XIAM.ETSTestHelper.initialize_endpoint_config()
      
      # Create test hierarchy with resilient pattern
      XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        create_extended_test_hierarchy()
      end, max_retries: 3, retry_delay: 200)
    end
    
    @tag :list_nodes
    test "lists nodes the user has access to", %{user: user, role: role, dept: dept, team: team} do
      with_valid_team_fixtures({user, role, dept, team}, fn user, role, dept, team ->
        # Extract IDs
        user_id = extract_user_id(user)
        role_id = extract_role_id(role)
        dept_id = extract_node_id(dept)
        _team_id = extract_node_id(team)  # Unused in this test
        
        # Grant access to department
        {:ok, _access} = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
          AccessManager.grant_access(user_id, dept_id, role_id)
        end, retry: 3)
        
        # List accessible nodes
        nodes_result = list_nodes_with_retry(user_id, 5)
        
        # Normalize response format
        nodes = normalize_node_response(nodes_result)
        
        # Extract node IDs for easier testing
        node_ids = extract_node_ids(nodes)
        
        # The department should be accessible
        assert Enum.member?(node_ids, dept_id), 
               "Department node #{dept_id} should be in accessible nodes list"
               
        # Depending on how inheritance works in the system, the team might also be accessible
        # This test just verifies the department access works correctly
        
        # Clean up
        {:ok, _} = ensure_access_revoked(user_id, dept.path)
      end)
    end
    
    @tag :list_nodes
    test "lists nodes includes children when access is inherited", %{user: user, role: role, dept: dept, team: team} do
      with_valid_team_fixtures({user, role, dept, team}, fn user, role, dept, team ->
        # Extract IDs
        user_id = extract_user_id(user)
        role_id = extract_role_id(role)
        dept_id = extract_node_id(dept)
        team_id = extract_node_id(team)  # Used in inheritance assertions below
        
        # Grant access to department only - team should inherit access based on hierarchy
        {:ok, _access} = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
          AccessManager.grant_access(user_id, dept_id, role_id)
        end, retry: 3)
        
        # List accessible nodes
        nodes_result = list_nodes_with_retry(user_id, 5)
        
        # Normalize response 
        nodes = normalize_node_response(nodes_result)
        
        # Extract node IDs for easier testing
        node_ids = extract_node_ids(nodes)
        
        # Both department and team should be accessible due to inheritance
        assert Enum.member?(node_ids, dept_id), 
               "Department node #{dept_id} should be in accessible nodes list"
               
        # This assertion depends on inheritance behavior - if your system doesn't inherit
        # access by default, you might need to adjust this test
        assert Enum.member?(node_ids, team_id), 
               "Team node #{team_id} should be in accessible nodes list due to inheritance"
        
        # Clean up - now handled with special case detection in ensure_nodes_access_revoked
        {:ok, _} = ensure_nodes_access_revoked(user_id, dept, team)
      end)
    end
    
    @tag :list_nodes
    test "returns empty list for user with no access", %{user: user} do
      with_valid_fixtures({user, nil, nil}, fn user, _role, _dept ->
        # Extract user ID
        user_id = extract_user_id(user)
        
        # List accessible nodes for user with no access
        nodes_result = list_nodes_with_retry(user_id, 5)
        
        # Normalize the response
        nodes = normalize_node_response(nodes_result)
        
        # Should return empty list
        assert Enum.empty?(nodes), 
               "Expected empty list for user with no access, but got: #{inspect(nodes)}"
      end)
    end
    
    @tag :list_nodes
    test "removes nodes from list after access revocation", %{user: user, role: role, dept: dept} do
      with_valid_fixtures({user, role, dept}, fn user, role, dept ->
        # Extract IDs
        user_id = extract_user_id(user)
        role_id = extract_role_id(role)
        dept_id = extract_node_id(dept)
        
        # Grant access
        {:ok, _access} = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
          AccessManager.grant_access(user_id, dept_id, role_id)
        end, retry: 3)
        
        # List nodes before revocation - should include the node
        nodes_before = list_nodes_with_retry(user_id, 5)
        assert_valid_node_response(nodes_before, dept_id)
        
        # Revoke access using path-based approach
        XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
          # First get all access grants for this user
          access_list = AccessManager.list_user_access(user_id)
          # Find and revoke any that match the target path
          Enum.each(access_list, fn access ->
            if access.access_path == dept.path do
              AccessManager.revoke_access(access.id)
            end
          end)
        end, retry: 3)
        
        # Ensure access is fully revoked with retry
        {:ok, _} = ensure_access_revoked(user_id, dept.path)
        
        # List nodes after revocation - should not include the node
        nodes_after = list_nodes_with_retry(user_id, 5)
        nodes = normalize_node_response(nodes_after)
        node_ids = extract_node_ids(nodes)
        
        # Assert node is not in the list
        refute Enum.member?(node_ids, dept_id), 
               "Node #{dept_id} should not be in the list after revocation, but got: #{inspect(node_ids)}"
      end)
    end
  end
end
