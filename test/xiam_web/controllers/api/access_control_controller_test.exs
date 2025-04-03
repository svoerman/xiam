defmodule XIAMWeb.API.AccessControlControllerTest do
  use XIAMWeb.ConnCase
  import Ecto.Query

  alias XIAM.Users.User
  alias XIAM.Repo
  alias XIAM.Auth.JWT
  alias Xiam.Rbac.Role
  alias Xiam.Rbac.Product
  alias Xiam.Rbac.AccessControl

  setup %{conn: conn} do
    # Generate a timestamp for unique test data
    timestamp = System.system_time(:second)
    
    # Clean up existing test data in the correct order (respecting foreign keys)
    # First delete entity access records that depend on users and roles
    Repo.delete_all(from ea in Xiam.Rbac.EntityAccess, 
                    join: u in User, on: ea.user_id == u.id,
                    where: like(u.email, "%access_ctrl_test%"))
    
    # Then delete other records
    Repo.delete_all(from u in User, where: like(u.email, "%access_ctrl_test%"))
    Repo.delete_all(from r in Role, where: like(r.name, "%Access_Test_Role%"))
    Repo.delete_all(from p in Product, where: like(p.product_name, "%Access_Test_Product%"))
    
    # Create a test user
    email = "access_ctrl_test_#{timestamp}@example.com"
    {:ok, user} = %User{}
      |> User.pow_changeset(%{
        email: email,
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Repo.insert()
      
    # Create a test role
    role_name = "Access_Test_Role_#{timestamp}"
    {:ok, role} = %Role{
      name: role_name,
      description: "Test role for access control"
    }
    |> Repo.insert()
    
    # Create a test product
    product_name = "Access_Test_Product_#{timestamp}"
    {:ok, product} = %Product{
      product_name: product_name,
      description: "Test product for access control"
    }
    |> Repo.insert()
    
    # Generate JWT token for authentication
    {:ok, token, _claims} = JWT.generate_token(user)
    
    # Set up authenticated connection
    conn = conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")
    
    # Register a teardown function that cleans up data
    on_exit(fn ->
      # Clean up entity access first (foreign key constraint)
      Repo.delete_all(from ea in Xiam.Rbac.EntityAccess, 
                      join: u in User, on: ea.user_id == u.id,
                      where: like(u.email, "%access_ctrl_test%"))
    end)
    
    %{
      conn: conn, 
      user: user, 
      role: role, 
      product: product, 
      token: token,
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
      
      # Make request
      conn = post(conn, ~p"/api/access", params)
      
      # Verify response
      assert %{"data" => data} = json_response(conn, 200)
      assert data["user_id"] == user.id
      assert data["entity_type"] == "test_entity"
      assert data["entity_id"] == 123
      assert data["role_id"] == role.id
    end
    
    test "get_user_access/2 retrieves user access", %{conn: conn, user: user, role: role} do
      # Create a test access record first
      {:ok, _access} = AccessControl.set_user_access(%{
        user_id: user.id,
        entity_type: "test_entity",
        entity_id: 456,
        role_id: role.id
      })
      
      # Make request
      conn = get(conn, ~p"/api/access?user_id=#{user.id}")
      
      # Verify response
      assert %{"data" => data} = json_response(conn, 200)
      assert is_list(data)
      assert length(data) >= 1
      assert Enum.all?(data, fn access -> access["user_id"] == user.id end)
    end
  end
  
  describe "product endpoints" do
    test "create_product/2 creates a product", %{conn: conn, timestamp: timestamp} do
      product_name = "New_Api_Product_#{timestamp}"
      params = %{"product_name" => product_name}
      
      # Make request
      conn = post(conn, ~p"/api/products", params)
      
      # Verify response
      assert %{"data" => data} = json_response(conn, 201)
      assert data["product_name"] == product_name
    end
    
    test "list_products/2 returns all products", %{conn: conn, product: product} do
      # Make request
      conn = get(conn, ~p"/api/products")
      
      # Verify response
      assert %{"data" => data} = json_response(conn, 200)
      assert is_list(data)
      assert length(data) >= 1
      assert Enum.any?(data, fn p -> p["id"] == product.id end)
    end
  end
  
  describe "capability endpoints" do
    test "create_capability/2 creates a capability", %{conn: conn, product: product, timestamp: timestamp} do
      capability_name = "test_api_capability_#{timestamp}"
      params = %{
        "product_id" => product.id,
        "capability_name" => capability_name,
        "description" => "Test capability description"
      }
      
      # Make request
      conn = post(conn, ~p"/api/capabilities", params)
      
      # Verify response
      assert %{"data" => data} = json_response(conn, 201)
      assert data["name"] == capability_name
      assert data["product_id"] == product.id
    end
    
    test "get_product_capabilities/2 returns product capabilities", %{conn: conn, product: product, timestamp: timestamp} do
      # Create a test capability first
      capability_name = "product_cap_test_#{timestamp}"
      {:ok, _capability} = AccessControl.create_capability(%{
        name: capability_name,
        description: "Test capability for product",
        product_id: product.id
      })
      
      # Make request
      conn = get(conn, ~p"/api/products/#{product.id}/capabilities")
      
      # Verify response
      assert %{"data" => data} = json_response(conn, 200)
      assert is_list(data)
      assert length(data) >= 1
      assert Enum.any?(data, fn c -> c["name"] == capability_name end)
    end
  end
end