defmodule XIAMWeb.API.HierarchyAccessControllerTest do
  use XIAMWeb.ConnCase, async: false
  
  # Import the ETSTestHelper to ensure proper test environment
    # Only include imports and aliases we actually use
  alias XIAM.Repo
  alias XIAM.Users.User
  alias XIAM.Auth.JWT
  alias XIAM.Hierarchy
  
  setup %{conn: conn} do
    # Generate a timestamp for unique test data with better uniqueness
    # Use a combination of millisecond timestamp and random component
    timestamp = "#{System.system_time(:millisecond)}_#{:rand.uniform(100_000)}"
    
    # Create a test user
    {:ok, user} = setup_test_user("hierarchy_access_test_#{timestamp}@example.com")
    
    # Create a test role with random suffix to avoid uniqueness conflicts
    {:ok, role} = setup_test_role("AccessViewer_#{timestamp}")
    
    # Assign role to user
    {:ok, user_with_role} = user
      |> User.role_changeset(%{role_id: role.id})
      |> Repo.update()
    
    # Create a sample hierarchy with unique names based on timestamp to avoid conflicts
    {:ok, root} = Hierarchy.create_node(%{name: "Root_#{timestamp}", node_type: "company"})
    {:ok, dept} = Hierarchy.create_node(%{name: "Department_#{timestamp}", node_type: "department", parent_id: root.id})
    {:ok, team} = Hierarchy.create_node(%{name: "Team_#{timestamp}", node_type: "team", parent_id: dept.id})
    
    # Grant access to the team node - using the correct arity for grant_access
    {:ok, access_grant} = Hierarchy.grant_access(user.id, team.id, role.id)
    
    # Add JWT authentication
    {:ok, token, _claims} = JWT.generate_token(user_with_role)
    
    conn = conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")

    %{
      conn: conn,
      user: user_with_role,
      role: role,
      root: root,
      department: dept,
      team: team,
      access_grant: access_grant,
      timestamp: timestamp
    }
  end

  # Helper functions
  defp setup_test_user(email) do
    # Create a minimal user record directly using Repo
    {:ok, user} = %User{}
      |> Ecto.Changeset.change(
        email: email,
        password_hash: Pow.Ecto.Schema.Password.pbkdf2_hash("Password123!")
      )
      |> Repo.insert()
    
    {:ok, user}
  end
  
  defp setup_test_role(name) do
    # Ensure the role name is unique to avoid conflicts across tests
    Xiam.Rbac.Role.changeset(%Xiam.Rbac.Role{}, %{
      name: name,
      description: "Test role for #{name}"
    })
    |> Repo.insert()
  end
  
  describe "check_access/2" do
    test "returns access status for a node", %{conn: conn, team: team, user: user, role: role} do
      
      # Use safely_execute_ets_operation for API requests
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        # Make the request to check access
        conn = get(conn, ~p"/api/v1/hierarchy/access/#{team.id}")
        
        # Verify the behavior - focus on response structure and content
        response = json_response(conn, 200)
        
        # Verify we get a data field with access information
        assert %{"data" => data} = response
        
        # Access should be granted as we set it up in the setup function
        assert data["has_access"] == true, "Expected user to have access to the node"
        assert data["node_id"] == team.id, "Expected node_id to match the requested node"
        assert data["user_id"] == user.id, "Expected user_id to match the current user"
        
        # Should include role information
        assert data["role"]["id"] == role.id, "Expected role information to be included"
      end)
    end
    
    test "returns false when user doesn't have access", %{conn: conn, root: root} do
      
      # Use safely_execute_ets_operation for API requests
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        # Make the request to check access to the root node (which user doesn't have direct access to)
        conn = get(conn, ~p"/api/v1/hierarchy/access/#{root.id}")
        
        # Verify the behavior - focus on response structure and content
        response = json_response(conn, 200)
        
        # Verify we get a data field with access information
        assert %{"data" => data} = response
        
        # Access should be denied as we didn't grant access to the root node
        assert data["has_access"] == false, "Expected user to not have access to the root node"
        assert data["node_id"] == root.id, "Expected node_id to match the requested node"
      end)
    end
    
    test "handles non-existent node", %{conn: conn} do
      
      # Use safely_execute_ets_operation for API requests
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        # Make the request to check access to a non-existent node
        conn = get(conn, ~p"/api/v1/hierarchy/access/999999999")
        
        # Verify the behavior - should return appropriate error
        response = json_response(conn, 404)
        
        # Should contain error information
        assert response["error"] != nil, "Expected error field when node doesn't exist"
      end)
    end
    
    test "handles inherited access", %{conn: conn, team: team, timestamp: timestamp} do
      
      # Create a child node under the team that the user has access to
      child_node = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        {:ok, child} = Hierarchy.create_node(%{
          name: "Project_#{timestamp}",
          node_type: "project", 
          parent_id: team.id
        })
        child
      end)
      
      # Use safely_execute_ets_operation for API requests
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        # Make the request to check access to the child node
        conn = get(conn, ~p"/api/v1/hierarchy/access/#{child_node.id}")
        
        # Verify the behavior - focus on response structure and content
        response = json_response(conn, 200)
        
        # Verify we get a data field with access information
        assert %{"data" => data} = response
        
        # Access should be granted through inheritance
        assert data["has_access"] == true, "Expected user to have inherited access to the child node"
        assert data["node_id"] == child_node.id, "Expected node_id to match the requested node"
        assert data["inherited"] == true, "Expected access to be marked as inherited"
        
        # Should include information about the source of the inheritance
        assert data["inherited_from"] != nil, "Expected inherited_from information"
        assert data["inherited_from"]["node_id"] == team.id, "Expected inheritance from the team node"
      end)
    end
  end
end
