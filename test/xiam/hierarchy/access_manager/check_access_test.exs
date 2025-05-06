defmodule XIAM.Hierarchy.AccessManager.CheckAccessTest do
  @moduledoc """
  Tests specific to the check_access functionality.
  """
  
  use XIAM.ResilientTestCase
  alias XIAM.Hierarchy.AccessManager
  
  describe "check_access/2" do
    setup do
      create_basic_test_hierarchy()
    end
    
    @tag :check_access
    test "returns true when user has access to a node", %{user: user, role: role, dept: dept} do
      with_valid_fixtures({user, role, dept}, fn user, role, dept ->
        # Extract IDs
        user_id = extract_user_id(user)
        role_id = extract_role_id(role)
        node_id = extract_node_id(dept)
        
        # Grant access
        {:ok, _access} = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
          AccessManager.grant_access(user_id, node_id, role_id)
        end, retry: 3)
        
        # Check access
        check_result = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
          AccessManager.check_access(user_id, node_id)
        end, retry: 3)
        
        # Assert access is granted
        assert_access_granted(check_result)
        
        # Clean up
        {:ok, _} = ensure_access_revoked(user_id, dept.path)
      end)
    end
    
    @tag :check_access
    test "returns false when user does not have access", %{user: user, dept: dept} do
      with_valid_fixtures({user, nil, dept}, fn user, _role, dept ->
        # Extract IDs
        user_id = extract_user_id(user)
        node_id = extract_node_id(dept)
        
        # Check access (without granting it first)
        check_result = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
          AccessManager.check_access(user_id, node_id)
        end, retry: 3)
        
        # Assert access is denied
        assert_access_denied(check_result)
      end)
    end
    
    @tag :check_access
    test "returns false after access is revoked", %{user: user, role: role, dept: dept} do
      with_valid_fixtures({user, role, dept}, fn user, role, dept ->
        # Extract IDs
        user_id = extract_user_id(user)
        role_id = extract_role_id(role)
        node_id = extract_node_id(dept)
        
        # Grant access
        {:ok, _access} = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
          AccessManager.grant_access(user_id, node_id, role_id)
        end, retry: 3)
        
        # Check access - should be granted
        check_result_before = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
          AccessManager.check_access(user_id, node_id)
        end, retry: 3)
        assert_access_granted(check_result_before)
        
        # Revoke access - need to get the access ID first and then use revoke_access/1
        XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
          # First get the access grants for this user
          access_list = AccessManager.list_user_access(user_id)
          # Find the access for this node and revoke it
          Enum.each(access_list, fn access ->
            if access.access_path == dept.path do
              AccessManager.revoke_access(access.id)
            end
          end)
        end, retry: 3)
        
        # Ensure access is fully revoked with retry
        {:ok, _} = ensure_check_access_revoked(user_id, node_id, dept.path)
        
        # Check access again - should be denied
        check_result_after = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
          AccessManager.check_access(user_id, node_id)
        end, retry: 3)
        assert_access_denied(check_result_after)
      end)
    end
    
    @tag :check_access
    test "handles check access with invalid node gracefully", %{user: user} do
      with_valid_fixtures({user, nil, nil}, fn user, _role, _dept ->
        # Extract user ID
        user_id = extract_user_id(user)
        
        # Try to check access with invalid node ID
        invalid_node_id = -1
        check_result = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
          AccessManager.check_access(user_id, invalid_node_id)
        end, retry: 3)
        
        # Should handle this gracefully (either return false or an error)
        case check_result do
          false -> assert true
          {:ok, %{has_access: false}} -> assert true
          {:error, _} -> assert true
          other ->
            # Should not be granted access to an invalid node
            assert_access_denied(other)
        end
      end)
    end
  end
end
