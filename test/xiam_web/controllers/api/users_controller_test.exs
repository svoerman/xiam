defmodule XIAMWeb.API.UsersControllerTest do
  use XIAMWeb.ConnCase, async: false
  import Mock
  import XIAM.ETSTestHelper

  alias XIAM.Repo
  alias XIAM.Rbac.ProductContext
  alias Xiam.Rbac
  alias XIAM.Users.User
  alias XIAM.Auth.JWT
  alias XIAM.Jobs.AuditLogger

  setup %{conn: conn} do
    # Explicitly start applications for database resilience
    # Following pattern from memory 995a5ecb-2a88-48d2-a3ce-f99c1269cafc
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    {:ok, _} = Application.ensure_all_started(:postgrex)
    
    # Use shared mode for database connections
    Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
    
    # Generate a timestamp for unique test data with better uniqueness
    # Use a combination of millisecond timestamp and random component
    timestamp = "#{System.system_time(:millisecond)}_#{:rand.uniform(100_000)}"

    # Clean up existing test data using direct SQL queries for better resilience
    XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
      # Using direct SQL query instead of Repo.delete_all
      {:ok, _} = Ecto.Adapters.SQL.query(Repo, "DELETE FROM users WHERE email LIKE $1", ["%users_api_test%"])
      {:ok, _} = Ecto.Adapters.SQL.query(Repo, "DELETE FROM roles WHERE name LIKE $1", ["%Users_Api_Role%"])
      {:ok, _} = Ecto.Adapters.SQL.query(Repo, "DELETE FROM capabilities WHERE name LIKE $1", ["%_user%"])
      {:ok, _} = Ecto.Adapters.SQL.query(Repo, "DELETE FROM products WHERE product_name LIKE $1", ["%Users_Test_Product%"])
    end, max_retries: 3, retry_delay: 200)

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
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Set up mock for audit logging to avoid actual DB calls
      with_mock AuditLogger, [log_action: fn _, _, _, _ -> {:ok, %{}} end] do
        # Use safely_execute_ets_operation for API requests
        XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
          # Request the first page with 10 users per page
          conn = get(conn, ~p"/api/users?page=1&per_page=10")

          # Check response - focus on behavior
          json_response = json_response(conn, 200)
          assert json_response["success"] == true
          
          # Verify we get a paginated list of users
          assert is_list(json_response["data"])
          assert json_response["meta"]["page"] == 1
          assert json_response["meta"]["per_page"] == 10

          # Verify that our test users are included in the response
          users_data = json_response["data"]
          assert Enum.any?(users_data, fn u -> u["id"] == admin.id end)
          assert Enum.any?(users_data, fn u -> u["id"] == user.id end)
        end)
      end
    end

    test "filters users by role", %{conn: conn, role: role, user: user} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Assign the test role to the test user using safely_execute_db_operation
      XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        {:ok, _updated_user} = user
          |> User.role_changeset(%{"role_id" => role.id})
          |> Repo.update()
      end)

      # Set up mock for audit logging
      with_mock AuditLogger, [log_action: fn _, _, _, _ -> {:ok, %{}} end] do
        # Use safely_execute_ets_operation for API requests
        XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
          # Request users filtered by role
          conn = get(conn, ~p"/api/users?role_id=#{role.id}")

          # Check response - focus on behavior
          json_response = json_response(conn, 200)
          assert json_response["success"] == true

          # Verify the filtering behavior works as expected
          users_data = json_response["data"]
          assert Enum.any?(users_data, fn u -> u["id"] == user.id end)
          assert Enum.all?(users_data, fn u -> u["role"] && u["role"]["id"] == role.id end)
        end)
      end
    end
  end

  describe "show/2" do
    test "returns a specific user", %{conn: conn, user: user} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Set up mock for audit logging
      with_mock AuditLogger, [log_action: fn _, _, _, _ -> {:ok, %{}} end] do
        # Use safely_execute_ets_operation for API requests
        XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
          # Request a specific user by ID
          conn = get(conn, ~p"/api/users/#{user.id}")

          # Check response - focus on behavior
          json_response = json_response(conn, 200)
          assert json_response["success"] == true
          
          # Verify we get the correct user data in the expected format
          assert json_response["data"]["id"] == user.id
          assert json_response["data"]["email"] == user.email
        end)
      end
    end

    test "returns 404 for non-existent user", %{conn: conn} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Set up mock for audit logging
      with_mock AuditLogger, [log_action: fn _, _, _, _ -> {:ok, %{}} end] do
        # Use safely_execute_ets_operation for API requests
        XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
          # Request a non-existent user
          conn = get(conn, ~p"/api/users/999999")

          # Check response - verify error handling behavior
          json_response = json_response(conn, 404)
          assert json_response["error"] == "User not found"
        end)
      end
    end
  end

  describe "create/2" do
    test "creates a new user with valid data", %{conn: conn, timestamp: timestamp} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Set up mock for audit logging
      with_mock AuditLogger, [log_action: fn _, _, _, _ -> {:ok, %{}} end] do
        # Use safely_execute_ets_operation for API requests
        XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
          # Prepare user data with unique email
          user_params = %{
            "email" => "new_user_#{timestamp}@example.com",
            "password" => "Password123!",
            "password_confirmation" => "Password123!"
          }

          # Send create request
          conn = post(conn, ~p"/api/users", %{"user" => user_params})

          # Check response - focus on behavior
          json_response = json_response(conn, 201)
          assert json_response["success"] == true
          assert json_response["data"]["email"] == "new_user_#{timestamp}@example.com"
          assert json_response["message"] == "User created successfully"
          
          # Store the user_id for database verification
          user_id = json_response["data"]["id"]
          
          # Verify user was created in database using safely_execute_db_operation
          XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
            created_user = Repo.get(User, user_id)
            assert created_user != nil
            assert created_user.email == "new_user_#{timestamp}@example.com"
          end)
        end)
      end
    end

    test "fails with invalid data", %{conn: conn} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Set up mock for audit logging
      with_mock AuditLogger, [log_action: fn _, _, _, _ -> {:ok, %{}} end] do
        # Use safely_execute_ets_operation for API requests
        XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
          # Invalid user data (missing password confirmation)
          user_params = %{
            "email" => "invalid@example.com",
            "password" => "Password123!"
            # Missing password_confirmation
          }

          # Send create request
          conn = post(conn, ~p"/api/users", %{"user" => user_params})

          # Check response - verify validation behavior
          json_response = json_response(conn, 422)
          assert json_response["error"] == "Failed to create user"
          assert json_response["details"]["password_confirmation"] != nil
        end)
      end
    end

    test "creates a user with a role", %{conn: conn, role: role, timestamp: timestamp} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Set up mock for audit logging
      with_mock AuditLogger, [log_action: fn _, _, _, _ -> {:ok, %{}} end] do
        # Use safely_execute_ets_operation for API requests
        XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
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
          
          # Use safely_execute_db_operation for database verification
          XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
            created_user = Repo.get(User, user_id) |> Repo.preload(:role)
            assert created_user.role_id == role.id
          end)
        end)
      end
    end
  end

  describe "update/2" do
    test "updates a user's email", %{conn: conn, user: user, timestamp: timestamp} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Set up mock for audit logging
      with_mock AuditLogger, [log_action: fn _, _, _, _ -> {:ok, %{}} end] do
        # Use safely_execute_ets_operation for API requests
        XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
          # Prepare update data with unique email
          update_params = %{
            "email" => "updated_#{timestamp}@example.com"
          }

          # Send update request
          conn = put(conn, ~p"/api/users/#{user.id}", %{"user" => update_params})

          # Check response - focus on behavior
          json_response = json_response(conn, 200)
          assert json_response["success"] == true
          assert json_response["message"] == "User updated successfully"
          assert json_response["data"]["email"] == "updated_#{timestamp}@example.com"

          # Verify user was updated in database using safely_execute_db_operation
          XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
            updated_user = Repo.get(User, user.id)
            assert updated_user.email == "updated_#{timestamp}@example.com"
          end)
        end)
      end
    end

    test "updates a user's role", %{conn: conn, user: user, role: role} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Set up mock for audit logging
      with_mock AuditLogger, [log_action: fn _, _, _, _ -> {:ok, %{}} end] do
        # Use safely_execute_ets_operation for API requests
        XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
          # Prepare update data
          update_params = %{
            "role_id" => role.id
          }

          # Send update request
          conn = put(conn, ~p"/api/users/#{user.id}", %{"user" => update_params})

          # Check response - focus on behavior
          json_response = json_response(conn, 200)
          assert json_response["success"] == true
          assert json_response["data"]["role"]["id"] == role.id

          # Verify user was updated in database using safely_execute_db_operation
          XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
            updated_user = Repo.get(User, user.id) |> Repo.preload(:role)
            assert updated_user.role_id == role.id
          end)
        end)
      end
    end

    test "fails to update with invalid data", %{conn: conn, user: user} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Set up mock for audit logging
      with_mock AuditLogger, [log_action: fn _, _, _, _ -> {:ok, %{}} end] do
        # Use safely_execute_ets_operation for API requests
        XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
          # Invalid update data (invalid email format)
          update_params = %{
            "email" => "not_an_email"
          }

          # Send update request
          conn = put(conn, ~p"/api/users/#{user.id}", %{"user" => update_params})

          # Check response - verify validation behavior
          json_response = json_response(conn, 422)
          assert json_response["success"] == false
          assert json_response["errors"] != %{}
        end)
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
    test "deletes a user", %{conn: conn, user: user} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Set up mock for audit logging
      with_mock AuditLogger, [log_action: fn _, _, _, _ -> {:ok, %{}} end] do
        # Use safely_execute_ets_operation for API requests
        XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
          # Send delete request
          conn = delete(conn, ~p"/api/users/#{user.id}")

          # Check response - verify behavior
          assert conn.status == 204
          
          # Verify user was deleted from database using safely_execute_db_operation
          XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
            deleted_user = Repo.get(User, user.id)
            assert deleted_user == nil
          end)
        end)
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
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Set up mock for audit logging
      with_mock AuditLogger, [log_action: fn _, _, _, _ -> {:ok, %{}} end] do
        # Use safely_execute_ets_operation for API requests
        XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
          # Try to delete a non-existent user
          conn = delete(conn, ~p"/api/users/999999")

          # Check response - verify error handling behavior
          assert json_response(conn, 404)["error"] == "User not found"
        end)
      end
    end
  end

  describe "anonymize/2" do
    test "anonymizes a user", %{conn: conn, timestamp: timestamp} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # First create a user to anonymize using safely_execute_db_operation
      user_to_anonymize = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        # Create a test user with unique email
        {:ok, user} = %User{}
          |> User.pow_changeset(%{
            email: "anonymize_me_#{timestamp}@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          })
          |> Repo.insert()
        user
      end)
      
      # Set up mock for audit logging
      with_mock AuditLogger, [log_action: fn _, _, _, _ -> {:ok, %{}} end] do
        # Use safely_execute_ets_operation for API requests
        XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
          # Send anonymize request
          conn = post(conn, ~p"/api/users/#{user_to_anonymize.id}/anonymize")

          # Check response - verify behavior
          response = json_response(conn, 200)
          assert response["success"] == true, "Expected successful anonymization"
          assert response["message"] =~ "anonymized", "Expected message indicating anonymization"
          
          # Verify user was anonymized but not deleted using safely_execute_db_operation
          XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
            anonymized_user = Repo.get(User, user_to_anonymize.id)
            
            # User should still exist
            assert anonymized_user != nil, "User should not be deleted during anonymization"
            
            # User's personal data should be anonymized
            assert anonymized_user.email != user_to_anonymize.email, "Email should be anonymized"
            assert anonymized_user.email =~ "anonymized", "Email should contain indication of anonymization"
            
            # Other checks for anonymization could include:
            # - Checking for associated data anonymization
            # - Verifying consent records are marked as withdrawn
            # - Confirming any personal fields are scrubbed
          end)
        end)
      end
    end
    
    test "returns 404 for non-existent user", %{conn: conn} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Set up mock for audit logging
      with_mock AuditLogger, [log_action: fn _, _, _, _ -> {:ok, %{}} end] do
        # Use safely_execute_ets_operation for API requests
        XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
          # Try to anonymize a non-existent user
          conn = post(conn, ~p"/api/users/999999/anonymize")

          # Check response - verify error handling behavior
          response = json_response(conn, 404)
          assert response["error"] == "User not found", "Expected not found error for non-existent user"
        end)
      end
    end
    
    test "prevents self-anonymization", %{conn: conn, admin: admin} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Set up mock for audit logging
      with_mock AuditLogger, [log_action: fn _, _, _, _ -> {:ok, %{}} end] do
        # Use safely_execute_ets_operation for API requests
        XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
          # Try to anonymize the current user (admin)
          conn = post(conn, ~p"/api/users/#{admin.id}/anonymize")

          # Check response - verify protection against self-anonymization
          response = json_response(conn, 403)
          assert response["error"] =~ "own account", "Expected error preventing self-anonymization"
          
          # Verify the admin user is not anonymized
          XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
            unchanged_user = Repo.get(User, admin.id)
            assert unchanged_user.email == admin.email, "Admin email should remain unchanged"
          end)
        end)
      end
    end
  end
end
