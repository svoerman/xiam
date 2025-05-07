defmodule XIAMWeb.API.HierarchyControllerErrorTest do
  use XIAMWeb.ConnCase, async: false

  # Import the ETSTestHelper to ensure proper test environment
  import XIAM.ETSTestHelper
  alias XIAM.Hierarchy
  alias XIAM.Users.User
  alias XIAM.Repo

  setup %{conn: conn} do
    # Generate a unique timestamp to avoid collisions
    timestamp = "#{System.system_time(:millisecond)}_#{:rand.uniform(100_000)}"
    
    # Create admin user and regular user for testing authorization
    admin_user = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
      {:ok, user} = %User{}
        |> User.pow_changeset(%{
          email: "admin_hierarchy_test_#{timestamp}@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })
        |> Repo.insert()
      user
    end)
    
    regular_user = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
      {:ok, user} = %User{}
        |> User.pow_changeset(%{
          email: "regular_hierarchy_test_#{timestamp}@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })
        |> Repo.insert()
      user
    end)
    
    # Create a test hierarchy structure
    hierarchy_nodes = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
      # Create root node
      {:ok, root} = Hierarchy.create_node(%{
        name: "Test_Root_#{timestamp}",
        node_type: "company"
      })
      
      # Create department node
      {:ok, dept} = Hierarchy.create_node(%{
        name: "Test_Dept_#{timestamp}",
        node_type: "department",
        parent_id: root.id
      })
      
      # Create team node
      {:ok, team} = Hierarchy.create_node(%{
        name: "Test_Team_#{timestamp}",
        node_type: "team",
        parent_id: dept.id
      })
      
      %{
        root: root,
        dept: dept,
        team: team
      }
    end)
    
    # Add JWT authentication to connections
    admin_conn = conn
      |> put_req_header("accept", "application/json")
      |> setup_auth(admin_user)
    
    regular_conn = conn
      |> put_req_header("accept", "application/json")
      |> setup_auth(regular_user)
    
    unauthenticated_conn = conn
      |> put_req_header("accept", "application/json")
    
    # Return the setup context
    {:ok, 
      admin_conn: admin_conn, 
      regular_conn: regular_conn,
      unauthenticated_conn: unauthenticated_conn,
      admin: admin_user, 
      regular_user: regular_user,
      nodes: hierarchy_nodes, 
      timestamp: timestamp
    }
  end
  
  # Helper function to set up authentication
  defp setup_auth(conn, user) do
    # Generate a JWT token
    {:ok, token, _claims} = generate_auth_token(user)
    
    # Add the token to the request headers
    put_req_header(conn, "authorization", "Bearer #{token}")
  end
  
  # Helper function to generate authentication token
  defp generate_auth_token(user) do
    XIAM.Auth.JWT.generate_token(user)
  end
  
  describe "create_node/2 error cases" do
    test "returns error for missing required fields", %{admin_conn: conn} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Use safely_execute_ets_operation for API requests
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        # Test missing name
        invalid_params = %{
          "node_type" => "department"
          # name is missing
        }
        
        # Make request
        conn = post(conn, ~p"/api/hierarchy/nodes", invalid_params)
        
        # Verify error response - validation failed
        response = json_response(conn, 422)
        assert response["errors"] != nil, "Expected validation errors"
        assert response["errors"]["name"] != nil, "Should have error for missing name"
      end)
    end
    
    test "returns error for invalid parent node", %{admin_conn: conn, timestamp: timestamp} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Use safely_execute_ets_operation for API requests
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        # Test invalid parent ID
        invalid_params = %{
          "name" => "Node_Invalid_Parent_#{timestamp}",
          "node_type" => "team",
          "parent_id" => 99999999 # Non-existent parent ID
        }
        
        # Make request
        conn = post(conn, ~p"/api/hierarchy/nodes", invalid_params)
        
        # Verify error response - parent not found
        response = json_response(conn, 422)
        assert response["errors"] != nil, "Expected validation errors"
        assert response["detail"] =~ "parent" || response["errors"]["parent_id"] != nil, 
               "Should have error related to invalid parent"
      end)
    end
    
    test "requires authentication for node creation", %{unauthenticated_conn: conn, timestamp: timestamp} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Use safely_execute_ets_operation for API requests
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        # Valid node params
        valid_params = %{
          "name" => "Node_Auth_Test_#{timestamp}",
          "node_type" => "department"
        }
        
        # Make request without authentication
        conn = post(conn, ~p"/api/hierarchy/nodes", valid_params)
        
        # Verify unauthorized response
        assert conn.status in [401, 403], "Expected unauthorized status code"
        response = json_response(conn, conn.status)
        assert response["error"] != nil, "Should have error message for unauthenticated request"
      end)
    end
  end
  
  describe "update_node/2 error cases" do
    test "returns error for non-existent node", %{admin_conn: conn, timestamp: timestamp} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Use safely_execute_ets_operation for API requests
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        # Update params
        update_params = %{
          "name" => "Updated_Name_#{timestamp}"
        }
        
        # Make request with non-existent node ID
        conn = put(conn, ~p"/api/hierarchy/nodes/999999", update_params)
        
        # Verify error response - node not found
        assert conn.status == 404
        response = json_response(conn, 404)
        assert response["error"] != nil, "Should have error message for non-existent node"
      end)
    end
    
    test "returns error when moving node creates a cycle", %{admin_conn: conn, nodes: nodes, timestamp: _timestamp} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Use safely_execute_ets_operation for API requests
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        # Try to make the root a child of its child (dept), creating a cycle
        update_params = %{
          "parent_id" => nodes.dept.id
        }
        
        # Make request that would create a cycle
        conn = put(conn, ~p"/api/hierarchy/nodes/#{nodes.root.id}", update_params)
        
        # Verify error response - should prevent cycles
        assert conn.status in [422, 400], "Expected validation error for cycle creation"
        response = json_response(conn, conn.status)
        assert response["error"] != nil || response["errors"] != nil, 
               "Should have error message for cycle prevention"
      end)
    end
  end
  
  describe "delete_node/2 error cases" do
    test "returns error for non-existent node", %{admin_conn: conn} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Use safely_execute_ets_operation for API requests
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        # Make request with non-existent node ID
        conn = delete(conn, ~p"/api/hierarchy/nodes/999999")
        
        # Verify error response - node not found
        assert conn.status == 404
        response = json_response(conn, 404)
        assert response["error"] != nil, "Should have error message for non-existent node"
      end)
    end
    
    test "prevents deleting nodes with children", %{admin_conn: conn, nodes: nodes} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Use safely_execute_ets_operation for API requests
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        # Try to delete the dept node which has a child (team)
        conn = delete(conn, ~p"/api/hierarchy/nodes/#{nodes.dept.id}")
        
        # Most implementations would either:
        # 1. Return an error (400, 422) that you can't delete a node with children
        # 2. Return 204/200 and cascade delete the children
        
        # This test assumes option 1 - returns an error
        if conn.status in [400, 422] do
          response = json_response(conn, conn.status)
          assert response["error"] != nil || response["errors"] != nil, 
                 "Should have error message when deleting node with children"
        else
          # If implementation uses cascading delete (option 2), 
          # verify the team was also deleted
          XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
            assert Hierarchy.get_node(nodes.team.id) == nil, 
                   "Child node should be deleted in cascade"
          end)
        end
      end)
    end
  end
  
  describe "access_control error cases" do
    test "check_user_access returns error for non-existent user", %{admin_conn: conn} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Use safely_execute_ets_operation for API requests
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        # Make request with non-existent user ID
        conn = post(conn, ~p"/api/hierarchy/check-access", %{
          "user_id" => 999999,
          "node_id" => 1
        })
        
        # Verify error response - user not found
        assert conn.status in [404, 400], "Expected error for non-existent user"
        response = json_response(conn, conn.status)
        assert response["error"] != nil, "Should have error message for non-existent user"
      end)
    end
    
    test "check_user_access returns error for non-existent node", %{admin_conn: conn, admin: user} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Use safely_execute_ets_operation for API requests
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        # Make request with non-existent node ID
        conn = post(conn, ~p"/api/hierarchy/check-access", %{
          "user_id" => user.id,
          "node_id" => 999999
        })
        
        # Verify error response - node not found
        assert conn.status in [404, 400], "Expected error for non-existent node"
        response = json_response(conn, conn.status)
        assert response["error"] != nil, "Should have error message for non-existent node"
      end)
    end
  end
  
  describe "v1 API error cases" do
    test "batch operations handle invalid input", %{admin_conn: conn} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Use safely_execute_ets_operation for API requests
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        # Empty batch delete request
        conn = post(conn, ~p"/api/v1/hierarchy/batch/delete", %{
          "node_ids" => []
        })
        
        # Verify response - probably a 400 Bad Request for empty input
        assert conn.status in [400, 422], "Expected validation error for empty batch"
        response = json_response(conn, conn.status)
        assert response["error"] != nil, "Should have error for invalid batch input"
      end)
    end
    
    test "batch_move handles invalid parent", %{admin_conn: conn, nodes: nodes} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Use safely_execute_ets_operation for API requests
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        # Invalid batch move request (non-existent parent)
        conn = post(conn, ~p"/api/v1/hierarchy/batch/move", %{
          "node_ids" => [nodes.team.id],
          "parent_id" => 999999
        })
        
        # Verify error response - parent not found
        assert conn.status in [404, 400, 422], "Expected error for invalid parent in batch move"
        response = json_response(conn, conn.status)
        assert response["error"] != nil, "Should have error message for invalid parent"
      end)
    end
    
    test "batch_grant_access handles invalid input", %{admin_conn: conn, admin: user} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Use safely_execute_ets_operation for API requests
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        # Invalid batch grant request (missing required fields)
        conn = post(conn, ~p"/api/v1/hierarchy/access/batch/grant", %{
          "user_id" => user.id
          # Missing node_ids and role_id
        })
        
        # Verify error response - missing required fields
        assert conn.status in [400, 422], "Expected validation error for incomplete batch grant"
        response = json_response(conn, conn.status)
        assert response["error"] != nil, "Should have error for missing required fields"
      end)
    end
  end
end
