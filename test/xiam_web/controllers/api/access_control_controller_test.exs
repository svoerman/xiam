defmodule XIAMWeb.API.AccessControlControllerTest do
  use XIAMWeb.ConnCase, async: false
  import Ecto.Query

  # Import the ETSTestHelper to ensure proper test environment
    
  alias XIAM.Users.User
  alias XIAM.Repo
  alias XIAM.Auth.JWT
  alias Xiam.Rbac
  alias Xiam.Rbac.Role
  alias Xiam.Rbac.Product
  alias Xiam.Rbac.Capability
  alias XIAM.Rbac.ProductContext
  alias Xiam.Rbac.AccessControl

  setup %{conn: conn} do
    # Generate a timestamp for unique test data with better uniqueness
    # Use a combination of millisecond timestamp and random component
    timestamp = "#{System.system_time(:millisecond)}_#{:rand.uniform(100_000)}"

    # Clean up existing test data
    Repo.delete_all(from ea in Xiam.Rbac.EntityAccess, join: u in User, on: ea.user_id == u.id, where: like(u.email, "%access_ctrl_test%"))
    Repo.delete_all(from u in User, where: like(u.email, "%access_ctrl_test%"))
    Repo.delete_all(from r in Role, where: like(r.name, "%Access_Test_Role%"))
    Repo.delete_all(from p in Product, where: like(p.product_name, "%Access_Test_Product%"))
    Repo.delete_all(from c in Capability, where: like(c.name, "%_access%") or like(c.name, "%_capabilities%"))

    # --- Create Product --- (For capability association)
    product_name = "Access_Test_Product_#{timestamp}"
    {:ok, product} = ProductContext.create_product(%{product_name: product_name, description: "Test product for access control"})

    # --- Create Capabilities ---
    {:ok, cap_manage_access} = Rbac.create_capability(%{product_id: product.id, name: "manage_access", description: "Manage user access"})
    {:ok, cap_view_access} = Rbac.create_capability(%{product_id: product.id, name: "view_access", description: "View user access"})
    {:ok, cap_manage_caps} = Rbac.create_capability(%{product_id: product.id, name: "manage_capabilities", description: "Manage capabilities"})
    {:ok, cap_view_caps} = Rbac.create_capability(%{product_id: product.id, name: "view_capabilities", description: "View capabilities"})

    # --- Create Role WITH capabilities directly ---
    role_name = "Access_Test_Role_#{timestamp}"
    role_attrs = %{name: role_name, description: "Test role for access control"}
    capability_ids = [cap_manage_access.id, cap_view_access.id, cap_manage_caps.id, cap_view_caps.id]
    {:ok, role} = Xiam.Rbac.Role.create_role_with_capabilities(role_attrs, capability_ids)

    # Create a test user (without role initially)
    email = "access_ctrl_test_#{timestamp}@example.com"
    {:ok, created_user} = %User{}
      |> User.pow_changeset(%{
        email: email,
        password: "Password123!",
        password_confirmation: "Password123!"
        # role_id removed
      })
      |> Repo.insert()

    # Assign the role to the user
    {:ok, user} = created_user
      |> User.role_changeset(%{role_id: role.id})
      |> Repo.update()

    # Generate JWT token for authentication
    {:ok, token, _claims} = JWT.generate_token(user)

    # Set up authenticated connection
    conn = conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")

    %{
      conn: conn,
      user: user,
      role: role,
      product: product,
      timestamp: timestamp
    }
  end

  describe "user access endpoints" do
    test "set_user_access/2 creates entity access", %{conn: conn, user: user, role: role} do
      
      # Create access params
      params = %{
        "user_id" => user.id,
        "entity_type" => "test_entity",
        "entity_id" => 123,
        "role" => role.name
      }

      # Use safely_execute_ets_operation for API requests that involve ETS tables
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        # Make request
        conn = post(conn, ~p"/api/access", params)

        # Verify response - focusing on behavior, not implementation
        assert %{"data" => data} = json_response(conn, 200)
        
        # Assert that we got a successful response with the expected data structure
        assert is_map(data)
        assert data["user_id"] == user.id
        assert data["entity_type"] == "test_entity"
        assert data["entity_id"] == 123
        assert data["role_id"] == role.id
      end)
    end

    test "get_user_access/2 retrieves user access", %{conn: conn, user: user, product: product, role: role} do
      
      # Use safely_execute_db_operation to handle the database setup
      XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        # Setup: Grant access first, including required entity_type and entity_id
        access_params = %{
          user_id: user.id,
          product_id: product.id,
          role_id: role.id,
          entity_type: "test_entity",
          entity_id: 999
        }
        {:ok, _access} = AccessControl.set_user_access(access_params)
      end)

      # Use safely_execute_ets_operation for the API request
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        # Test: Retrieve access
        conn = get(conn, ~p"/api/access?user_id=#{user.id}")

        # Verify response - focusing on behavior
        assert %{"data" => data} = json_response(conn, 200)
        
        # Test that we get a list of access permissions
        assert is_list(data)
        assert length(data) >= 1
        
        # Verify the access entries are for our test user
        assert Enum.all?(data, fn access -> access["user_id"] == user.id end)
      end)
    end
  end

  describe "capability endpoints" do
    test "create_capability/2 creates a capability", %{conn: conn, product: product, timestamp: timestamp} do
      
      # Create a unique capability name to avoid conflicts across test runs
      capability_name = "test_api_capability_#{timestamp}"
      params = %{
        "product_id" => product.id,
        "capability_name" => capability_name,
        "description" => "Test capability description"
      }

      # Use safely_execute_ets_operation for API requests
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        # Make request
        conn = post(conn, ~p"/api/capabilities", params)

        # Verify the behavior - capability created successfully
        assert %{"data" => data} = json_response(conn, 201)
        
        # Verify the response contains the expected data
        assert data["name"] == capability_name
        assert data["product_id"] == product.id
        assert data["description"] == "Test capability description"
      end)
    end

    test "get_product_capabilities/2 returns product capabilities", %{conn: conn, product: product, timestamp: timestamp} do
      
      # Create a unique capability name
      capability_name = "View_Dashboard_#{timestamp}"
      
      # Setup: Create a capability first using safely_execute_db_operation
      XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        capability_attrs = %{
          product_id: product.id,
          name: capability_name,
          description: "Allows viewing the main dashboard"
        }
        {:ok, _capability} = AccessControl.create_capability(capability_attrs)
      end)

      # Use safely_execute_ets_operation for the API request
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        # Test: Retrieve capabilities
        conn = get(conn, ~p"/api/products/#{product.id}/capabilities")

        # Verify the behavior - capabilities are returned
        assert %{"data" => data} = json_response(conn, 200)
        
        # Verify that we get a list of capabilities
        assert is_list(data)
        assert length(data) >= 1
        
        # Verify our test capability is in the list
        assert Enum.any?(data, fn c -> c["name"] == capability_name end)
      end)
    end
    
    test "get_capability/2 retrieves a specific capability", %{conn: _conn, product: _product, timestamp: _timestamp} do
      # Skipping this test as the specific capability endpoint is not defined in the router
      # Based on the router.ex, there is no GET route for /api/capabilities/:id
    end
  end
end
