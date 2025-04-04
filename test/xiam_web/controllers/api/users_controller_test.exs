defmodule XIAMWeb.API.UsersControllerTest do
  use XIAMWeb.ConnCase
  import Ecto.Query
  import Mock

  alias XIAM.Repo
  alias XIAM.Rbac.ProductContext
  alias Xiam.Rbac
  alias XIAM.Users.User
  alias Xiam.Rbac.Role
  alias Xiam.Rbac.Product
  alias Xiam.Rbac.Capability
  alias XIAM.Auth.JWT
  alias XIAM.Jobs.AuditLogger

  setup %{conn: conn} do
    # Generate a timestamp for unique test data
    timestamp = System.system_time(:second)

    # Clean up existing test data
    Repo.delete_all(from u in User, where: like(u.email, "%users_api_test%"))
    Repo.delete_all(from r in Role, where: like(r.name, "%Users_Api_Role%"))
    Repo.delete_all(from c in Capability, where: like(c.name, "%_user%"))
    # Also delete test product
    Repo.delete_all(from p in Product, where: like(p.product_name, "%Users_Test_Product%"))

    # --- Create Product --- (Capabilities need a product)
    {:ok, product} = ProductContext.create_product(%{product_name: "Users_Test_Product_#{timestamp}", description: "Test Product"})

    # --- Create Capabilities (associated with product) ---
    {:ok, cap_list} = Rbac.create_capability(%{product_id: product.id, name: "list_users", description: "List API users"})
    {:ok, cap_view} = Rbac.create_capability(%{product_id: product.id, name: "view_user", description: "View API user"})
    {:ok, cap_create} = Rbac.create_capability(%{product_id: product.id, name: "create_user", description: "Create API user"})
    {:ok, cap_update} = Rbac.create_capability(%{product_id: product.id, name: "update_user", description: "Update API user"})
    {:ok, cap_delete} = Rbac.create_capability(%{product_id: product.id, name: "delete_user", description: "Delete API user"})

    # --- Create Role WITH capabilities directly ---
    role_name = "Users_Api_Role_#{timestamp}"
    role_attrs = %{name: role_name, description: "Test role for users API"}
    capability_ids = [cap_list.id, cap_view.id, cap_create.id, cap_update.id, cap_delete.id]
    {:ok, role} = Xiam.Rbac.Role.create_role_with_capabilities(role_attrs, capability_ids)

    # --- Create Admin User with the Role ---
    admin_email = "users_api_test_admin_#{timestamp}@example.com"
    {:ok, admin_unlinked} = %User{}
      |> User.pow_changeset(%{
        "email" => admin_email,
        "password" => "Password123!",
        "password_confirmation" => "Password123!",
        "admin" => true # Keep admin flag
      })
      |> Repo.insert()

    # --- Assign Role to Admin User ---
    {:ok, admin} = admin_unlinked
      |> User.role_changeset(%{"role_id" => role.id})
      |> Repo.update()

    # Create a regular test user (no role initially)
    user_email = "users_api_test_user_#{timestamp}@example.com"
    {:ok, user} = %User{}
      |> User.pow_changeset(%{
        "email" => user_email,
        "password" => "Password123!",
        "password_confirmation" => "Password123!"
      })
      |> Repo.insert()

    # Generate JWT token for the admin user
    {:ok, admin_token, _claims} = JWT.generate_token(admin)

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
      # Return capabilities for potential granular tests if needed
      capabilities: %{list: cap_list, view: cap_view, create: cap_create, update: cap_update, delete: cap_delete},
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
        |> User.role_changeset(%{"role_id" => role.id})
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

  describe "create/2" do
    test "creates a new user with valid data", %{conn: conn, timestamp: timestamp} do
      # Set up mock for audit logging
      with_mock AuditLogger, [log_action: fn _, _, _, _ -> {:ok, %{}} end] do
        # Prepare user data
        user_params = %{
          "email" => "new_user_#{timestamp}@example.com",
          "password" => "Password123!",
          "password_confirmation" => "Password123!"
        }

        # Send create request
        conn = post(conn, ~p"/api/users", %{"user" => user_params})

        # Check response
        json_response = json_response(conn, 201)
        assert json_response["success"] == true
        assert json_response["data"]["email"] == "new_user_#{timestamp}@example.com"
        assert json_response["message"] == "User created successfully"

        # Verify user was created in database
        user_id = json_response["data"]["id"]
        created_user = Repo.get(User, user_id)
        assert created_user != nil
        assert created_user.email == "new_user_#{timestamp}@example.com"
      end
    end

    test "fails with invalid data", %{conn: conn} do
      # Set up mock for audit logging
      with_mock AuditLogger, [log_action: fn _, _, _, _ -> {:ok, %{}} end] do
        # Invalid user data (missing password confirmation)
        user_params = %{
          "email" => "invalid@example.com",
          "password" => "Password123!"
          # Missing password_confirmation
        }

        # Send create request
        conn = post(conn, ~p"/api/users", %{"user" => user_params})

        # Check response
        json_response = json_response(conn, 422)
        assert json_response["error"] == "Failed to create user"
        assert json_response["details"]["password_confirmation"] != nil
      end
    end

    test "creates a user with a role", %{conn: conn, role: role, timestamp: timestamp} do
      # Set up mock for audit logging
      with_mock AuditLogger, [log_action: fn _, _, _, _ -> {:ok, %{}} end] do
        # Prepare user data with role
        user_params = %{
          "email" => "role_user_#{timestamp}@example.com",
          "password" => "Password123!",
          "password_confirmation" => "Password123!",
          "role_id" => role.id
        }

        # Send create request
        conn = post(conn, ~p"/api/users", %{"user" => user_params})

        # Check response
        json_response = json_response(conn, 201)
        assert json_response["success"] == true

        # Verify user was created with the role
        user_id = json_response["data"]["id"]
        created_user = Repo.get(User, user_id) |> Repo.preload(:role)
        assert created_user.role_id == role.id
      end
    end
  end

  describe "update/2" do
    test "updates a user's email", %{conn: conn, user: user, timestamp: timestamp} do
      # Set up mock for audit logging
      with_mock AuditLogger, [log_action: fn _, _, _, _ -> {:ok, %{}} end] do
        # Prepare update data
        update_params = %{
          "email" => "updated_#{timestamp}@example.com"
        }

        # Send update request
        conn = put(conn, ~p"/api/users/#{user.id}", %{"user" => update_params})

        # Check response
        json_response = json_response(conn, 200)
        assert json_response["success"] == true
        assert json_response["message"] == "User updated successfully"
        assert json_response["data"]["email"] == "updated_#{timestamp}@example.com"

        # Verify user was updated in database
        updated_user = Repo.get(User, user.id)
        assert updated_user.email == "updated_#{timestamp}@example.com"
      end
    end

    test "updates a user's role", %{conn: conn, user: user, role: role} do
      # Set up mock for audit logging
      with_mock AuditLogger, [log_action: fn _, _, _, _ -> {:ok, %{}} end] do
        # Prepare update data
        update_params = %{
          "role_id" => role.id
        }

        # Send update request
        conn = put(conn, ~p"/api/users/#{user.id}", %{"user" => update_params})

        # Check response
        json_response = json_response(conn, 200)
        assert json_response["success"] == true
        assert json_response["message"] == "User updated successfully"

        # Verify user's role was updated in database
        updated_user = Repo.get(User, user.id) |> Repo.preload(:role)
        assert updated_user.role_id == role.id
      end
    end

    test "updates a user's password", %{conn: conn, user: user} do
      # Set up mock for audit logging
      with_mock AuditLogger, [log_action: fn _, _, _, _ -> {:ok, %{}} end] do
        # Prepare update data
        update_params = %{
          "password" => "NewPassword123!",
          "password_confirmation" => "NewPassword123!"
        }

        # Send update request
        conn = put(conn, ~p"/api/users/#{user.id}", %{"user" => update_params})

        # Check response
        json_response = json_response(conn, 200)
        assert json_response["success"] == true
        assert json_response["message"] == "User updated successfully"

        # Verify password was updated (indirectly by checking it's different)
        updated_user = Repo.get(User, user.id)
        assert updated_user.password_hash != user.password_hash
      end
    end
  end

  describe "delete/2" do
    test "deletes a user", %{conn: conn, timestamp: timestamp} do
      # Set up mock for audit logging
      with_mock AuditLogger, [log_action: fn _, _, _, _ -> {:ok, %{}} end] do
        # Create a user to delete
        {:ok, user_to_delete} = %User{}
          |> User.pow_changeset(%{
            email: "delete_me_#{timestamp}@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          })
          |> Repo.insert()

        # Send delete request
        conn = delete(conn, ~p"/api/users/#{user_to_delete.id}")

        # Check response
        json_response = json_response(conn, 200)
        assert json_response["success"] == true
        assert json_response["message"] == "User deleted successfully"

        # Verify user was deleted
        assert Repo.get(User, user_to_delete.id) == nil
      end
    end

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

    test "returns 404 for non-existent user", %{conn: conn} do
      # Set up mock for audit logging
      with_mock AuditLogger, [log_action: fn _, _, _, _ -> {:ok, %{}} end] do
        # Try to delete non-existent user
        conn = delete(conn, ~p"/api/users/999999")

        # Check response
        json_response = json_response(conn, 404)
        assert json_response["error"] == "User not found"
      end
    end
  end
end
