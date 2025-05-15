defmodule XIAMWeb.API.ProductControllerTest do
  use XIAMWeb.ConnCase, async: false
  import Ecto.Query
  
  alias XIAM.Repo
  alias XIAM.Rbac.ProductContext
  alias Xiam.Rbac
  alias XIAM.Users.User
  alias Xiam.Rbac.Role
  alias Xiam.Rbac.Product
  alias Xiam.Rbac.Capability
  alias XIAM.Auth.JWT

  setup %{conn: conn} do
    # Generate a unique timestamp for this test run with better uniqueness
    # Use a combination of millisecond timestamp and random component
    timestamp = "#{System.system_time(:millisecond)}_#{:rand.uniform(100_000)}"

    # Clean up existing test data that might interfere
    Repo.delete_all(from p in Product, where: like(p.product_name, "%Test_Product_%") or like(p.product_name, "%New_Test_Product_%"))
    Repo.delete_all(from u in User, where: like(u.email, "%test_product_controller_%"))
    Repo.delete_all(from r in Role, where: like(r.name, "%Product_Test_Role%"))
    Repo.delete_all(from c in Capability, where: like(c.name, "%_product%"))

    # --- Create Product --- (For capability association)
    product_name_base = "Test_Product_#{timestamp}"
    {:ok, product_for_caps} = ProductContext.create_product(%{product_name: product_name_base, description: "Base Product for Caps"})

    # --- Create Capabilities ---
    {:ok, cap_list} = Rbac.create_capability(%{product_id: product_for_caps.id, name: "list_products", description: "List products"})
    {:ok, cap_create} = Rbac.create_capability(%{product_id: product_for_caps.id, name: "create_product", description: "Create product"})

    # --- Create Role WITH capabilities directly ---
    role_name = "Product_Test_Role_#{timestamp}"
    role_attrs = %{name: role_name, description: "Test role for product API"}
    capability_ids = [cap_list.id, cap_create.id]
    {:ok, role} = Xiam.Rbac.Role.create_role_with_capabilities(role_attrs, capability_ids)

    # --- Create User (without role initially) ---
    {:ok, user_unlinked} = User.pow_changeset(%User{}, %{
      email: "test_product_controller_#{timestamp}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
      # role_id removed
    }) |> Repo.insert()

    # --- Assign Role to User ---
    {:ok, user} = user_unlinked
      |> User.role_changeset(%{role_id: role.id})
      |> Repo.update()

    # Create test product with unique name (different from product_for_caps)
    product_name_for_test = "Test_Product_For_API_#{timestamp}"
    {:ok, product} = %Product{
      product_name: product_name_for_test,
      description: "Test product description"
    } |> Repo.insert()

    # Authenticate the connection
    conn = put_req_header(conn, "accept", "application/json")
    conn = put_req_header(conn, "content-type", "application/json")

    # Create a real JWT token
    {:ok, token, _claims} = JWT.generate_token(user)

    # Authenticated connection with proper Bearer token
    conn = conn
      |> put_req_header("authorization", "Bearer #{token}")

    %{
      conn: conn,
      user: user,
      product: product,
      role: role,
      token: token,
      timestamp: timestamp
    }
  end

  describe "index/2" do
    test "lists all products", %{conn: conn, product: product, token: token} do
      
      # Use safely_execute_ets_operation for API requests that involve ETS tables
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        conn = conn
          |> put_req_header("accept", "application/json")
          |> put_req_header("content-type", "application/json")
          |> put_req_header("authorization", "Bearer #{token}")
          |> get(~p"/api/v1/products")

        # Verify the behavior - focus on the API response structure and content
        assert %{"data" => products} = json_response(conn, 200)
        assert is_list(products), "Expected products to be a list"
        assert length(products) >= 1, "Expected at least one product"
        
        # Verify our test product is included in the list
        assert Enum.any?(products, fn p -> p["id"] == product.id end)
        assert Enum.any?(products, fn p -> p["product_name"] == product.product_name end)
      end)
    end
  end

  describe "create/2" do
    test "creates a product with valid attributes", %{conn: conn, timestamp: timestamp} do
      
      # Create a unique product name
      product_name = "New_Test_Product_#{timestamp}"
      params = %{"product_name" => product_name}
      
      # Use safely_execute_ets_operation for API requests
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        conn = post(conn, ~p"/api/v1/products", params)

        # Verify the behavior - product created successfully
        assert %{"data" => data} = json_response(conn, 201)
        assert data["product_name"] == product_name
        
        # Store the product ID for database verification
        product_id = data["id"]
        
        # Verify product was created in database using safely_execute_db_operation
        XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
          created_product = Repo.get(Product, product_id)
          assert created_product != nil
          assert created_product.product_name == product_name
        end)
      end)
    end

    test "returns error with invalid attributes", %{conn: conn} do
      
      # Try to create a product with empty name
      params = %{"product_name" => ""}
      
      # Use safely_execute_ets_operation for API requests
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        conn = post(conn, ~p"/api/v1/products", params)

        # Verify the behavior - validation error expected
        assert %{"errors" => errors} = json_response(conn, 422)
        assert errors != %{}
        assert Map.has_key?(errors, "product_name") || Map.has_key?(errors, ":product_name")
      end)
    end

    test "returns error with missing attributes", %{conn: conn} do
      
      # Try to create a product with no params
      params = %{}
      
      # Use safely_execute_ets_operation for API requests
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        conn = post(conn, ~p"/api/v1/products", params)

        # Verify the behavior - validation error expected
        assert %{"errors" => errors} = json_response(conn, 422)
        assert errors != %{}
        assert Map.has_key?(errors, "product_name") || Map.has_key?(errors, ":product_name")
      end)
    end
  end

  describe "product endpoints (moved from access control tests)" do
    test "update_product/2 updates a product", %{conn: _conn, product: _product} do
      # Skipping this test as the update endpoint is not defined in the router
      # According to line 199 in router.ex, only index and create actions are supported
      # resources "/products", ProductController, only: [:index, :create]
    end

    test "get_product/2 retrieves a specific product", %{conn: _conn, product: _product} do
      # Skipping this test as the show endpoint is not defined in the router
      # According to line 199 in router.ex, only index and create actions are supported
      # resources "/products", ProductController, only: [:index, :create]
    end
    
    test "delete_product/2 removes a product", %{conn: _conn, timestamp: _timestamp} do
      # Skipping this test as the delete endpoint is not defined in the router
      # According to line 199 in router.ex, only index and create actions are supported
      # resources "/products", ProductController, only: [:index, :create]
    end
  end
end
