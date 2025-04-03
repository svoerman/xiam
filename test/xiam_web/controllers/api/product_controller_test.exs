defmodule XIAMWeb.API.ProductControllerTest do
  use XIAMWeb.ConnCase
  import Ecto.Query

  alias XIAM.Users.User
  alias XIAM.Repo
  alias Xiam.Rbac.Product
  alias XIAM.Auth.JWT

  setup %{conn: conn} do
    # Generate a unique timestamp for this test run
    timestamp = System.system_time(:second)
    
    # Clean up existing test data that might interfere
    Repo.delete_all(from p in Product, where: like(p.product_name, "%Test_Product_%"))
    Repo.delete_all(from p in Product, where: like(p.product_name, "%New_Test_Product_%"))
    Repo.delete_all(from u in User, where: like(u.email, "%test_product_controller_%"))
    
    # Create test user with correct fields for Pow and unique email
    {:ok, user} = User.pow_changeset(%User{}, %{
      email: "test_product_controller_#{timestamp}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    }) |> Repo.insert()

    # Create test product with unique name
    product_name = "Test_Product_#{timestamp}"
    {:ok, product} = %Product{
      product_name: product_name,
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
      |> assign(:current_user, user)

    %{
      conn: conn,
      user: user,
      product: product,
      token: token,
      timestamp: timestamp
    }
  end

  describe "index/2" do
    test "lists all products", %{conn: conn, product: product, token: token} do
      conn = conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("content-type", "application/json")
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/products")
      
      assert %{"data" => products} = json_response(conn, 200)
      assert length(products) >= 1
      assert Enum.any?(products, fn p -> p["id"] == product.id end)
      assert Enum.any?(products, fn p -> p["product_name"] == product.product_name end)
    end
  end

  describe "create/2" do
    test "creates a product with valid attributes", %{conn: conn, timestamp: timestamp} do
      product_name = "New_Test_Product_#{timestamp}"
      params = %{"product_name" => product_name}
      conn = post(conn, ~p"/api/products", params)
      
      assert %{"data" => data} = json_response(conn, 201)
      assert data["product_name"] == product_name
    end

    test "returns error with invalid attributes", %{conn: conn} do
      params = %{"product_name" => ""}
      conn = post(conn, ~p"/api/products", params)
      
      assert %{"errors" => _errors} = json_response(conn, 422)
    end

    test "returns error with missing attributes", %{conn: conn} do
      params = %{}
      conn = post(conn, ~p"/api/products", params)
      
      assert %{"errors" => _errors} = json_response(conn, 422)
    end
  end
end