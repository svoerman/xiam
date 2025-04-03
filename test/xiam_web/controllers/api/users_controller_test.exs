defmodule XIAMWeb.API.UsersControllerTest do
  use XIAMWeb.ConnCase
  import Ecto.Query
  import Mock

  alias XIAM.Users.User
  alias XIAM.Repo
  alias XIAM.Auth.JWT
  alias Xiam.Rbac.Role
  alias XIAM.Jobs.AuditLogger

  setup %{conn: conn} do
    # Generate a timestamp for unique test data
    timestamp = System.system_time(:second)
    
    # Clean up existing test data
    Repo.delete_all(from u in User, where: like(u.email, "%users_api_test%"))
    Repo.delete_all(from r in Role, where: like(r.name, "%Users_Api_Role%"))
    
    # Create a test admin user with a unique email
    admin_email = "users_api_test_admin_#{timestamp}@example.com"
    {:ok, admin} = %User{}
      |> User.pow_changeset(%{
        email: admin_email,
        password: "Password123!",
        password_confirmation: "Password123!",
        admin: true
      })
      |> Repo.insert()
      
    # Create a regular test user with a unique email
    user_email = "users_api_test_user_#{timestamp}@example.com"
    {:ok, user} = %User{}
      |> User.pow_changeset(%{
        email: user_email,
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Repo.insert()
      
    # Create a test role with a unique name
    role_name = "Users_Api_Role_#{timestamp}"
    {:ok, role} = %Role{
      name: role_name,
      description: "Test role for users API"
    }
    |> Repo.insert()
    
    # Generate JWT tokens for authentication
    {:ok, admin_token, _claims} = JWT.generate_token(admin)
    {:ok, user_token, _claims} = JWT.generate_token(user)
    
    # Create an authenticated connection using the admin token
    conn = conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "Bearer #{admin_token}")
      
    %{
      conn: conn,
      admin: admin,
      user: user,
      role: role,
      admin_token: admin_token,
      user_token: user_token,
      timestamp: timestamp
    }
  end
  
  describe "index/2" do
    test "lists users with pagination", %{conn: conn, admin: admin, user: user} do
      # Set up mock for audit logging to avoid actual DB calls
      with_mock AuditLogger, [log_action: fn _, _, _, _ -> {:ok, %{}} end] do
        # Request the first page with 10 users per page
        conn = get(conn, ~p"/api/users?page=1&per_page=10")
        
        # Check response
        json_response = json_response(conn, 200)
        assert json_response["success"] == true
        assert is_list(json_response["data"])
        assert json_response["meta"]["page"] == 1
        assert json_response["meta"]["per_page"] == 10
        
        # Verify that our test users are included in the response
        users_data = json_response["data"]
        assert Enum.any?(users_data, fn u -> u["id"] == admin.id end)
        assert Enum.any?(users_data, fn u -> u["id"] == user.id end)
      end
    end
    
    test "filters users by role", %{conn: conn, role: role, user: user} do
      # Assign the test role to the test user
      {:ok, _updated_user} = user
        |> User.role_changeset(%{role_id: role.id})
        |> Repo.update()
      
      # Set up mock for audit logging
      with_mock AuditLogger, [log_action: fn _, _, _, _ -> {:ok, %{}} end] do
        # Request users filtered by role
        conn = get(conn, ~p"/api/users?role_id=#{role.id}")
        
        # Check response
        json_response = json_response(conn, 200)
        assert json_response["success"] == true
        
        # Verify the user with the role is included
        users_data = json_response["data"]
        assert Enum.any?(users_data, fn u -> u["id"] == user.id end)
        assert Enum.all?(users_data, fn u -> u["role"] && u["role"]["id"] == role.id end)
      end
    end
  end
  
  describe "show/2" do
    test "returns a specific user", %{conn: conn, user: user} do
      # Set up mock for audit logging
      with_mock AuditLogger, [log_action: fn _, _, _, _ -> {:ok, %{}} end] do
        # Request a specific user by ID
        conn = get(conn, ~p"/api/users/#{user.id}")
        
        # Check response
        json_response = json_response(conn, 200)
        assert json_response["success"] == true
        assert json_response["data"]["id"] == user.id
        assert json_response["data"]["email"] == user.email
      end
    end
    
    test "returns 404 for non-existent user", %{conn: conn} do
      # Set up mock for audit logging
      with_mock AuditLogger, [log_action: fn _, _, _, _ -> {:ok, %{}} end] do
        # Request a non-existent user
        conn = get(conn, ~p"/api/users/999999")
        
        # Check response
        json_response = json_response(conn, 404)
        assert json_response["error"] == "User not found"
      end
    end
  end

  describe "delete/2" do
    test "prevents self-deletion", %{conn: conn, admin: admin} do
      # Set up mock for audit logging
      with_mock AuditLogger, [log_action: fn _, _, _, _ -> {:ok, %{}} end] do
        # Try to delete the current user (admin)
        conn = delete(conn, ~p"/api/users/#{admin.id}")
        
        # Check response
        json_response = json_response(conn, 403)
        assert json_response["error"] == "Cannot delete your own account"
        
        # Verify the user is not deleted
        assert Repo.get(User, admin.id) != nil
      end
    end
  end
end