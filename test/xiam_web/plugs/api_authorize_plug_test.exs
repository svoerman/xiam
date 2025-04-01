defmodule XIAMWeb.Plugs.APIAuthorizePlugTest do
  use XIAMWeb.ConnCase
  
  import Ecto.Query
  
  alias XIAMWeb.Plugs.APIAuthorizePlug
  alias XIAM.Users.User
  alias Xiam.Rbac.{Role, Capability}
  alias XIAM.Repo

  setup %{conn: conn} do
    # Generate a unique email for this test run to avoid conflicts
    timestamp = System.system_time(:second)
    test_email = "api_authorize_test_#{timestamp}@example.com"
    
    # Delete any existing test users to avoid conflicts
    Repo.delete_all(from u in User, where: like(u.email, "api_authorize_test%"))
    
    # Create a test user
    {:ok, user} = %User{}
      |> User.pow_changeset(%{
        email: test_email,
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Repo.insert()

    # First, clean up existing role that might conflict
    Repo.delete_all(from r in Role, where: like(r.name, "%Authorize Test Role%"))
    
    # Create a role with test capabilities with a unique name
    role_name = "Authorize Test Role #{timestamp}"
    
    # Try to find the role first in case it exists
    role = case Repo.get_by(Role, name: role_name) do
      nil ->
        # Create a new role
        {:ok, role} = %Role{
          name: role_name,
          description: "Role for testing authorization"
        }
        |> Repo.insert()
        role
      existing_role ->
        # Use the existing role
        existing_role
    end

    # Clean up existing products
    Repo.delete_all(from p in Xiam.Rbac.Product, where: like(p.product_name, "%API Auth Test Product%"))
    
    # Create a product for capabilities with unique name
    product_name = "API Auth Test Product #{timestamp}"
    
    # Try to find the product first or create a new one
    product = case Repo.get_by(Xiam.Rbac.Product, product_name: product_name) do
      nil ->
        {:ok, product} = %Xiam.Rbac.Product{
          product_name: product_name,
          description: "Product for testing API auth"
        }
        |> Repo.insert()
        product
      existing ->
        existing
    end
    
    # Clean up existing capabilities
    Repo.delete_all(from c in Capability, where: like(c.name, "%test_capability%"))
    
    # Create test capabilities with unique name
    capability_name = "test_capability_#{timestamp}"
    
    # Try to find the capability first or create a new one
    capability1 = case Repo.get_by(Capability, name: capability_name) do
      nil ->
        {:ok, cap} = %Capability{
          name: capability_name,
          description: "Test capability",
          product_id: product.id
        }
        |> Repo.insert()
        cap
      existing ->
        existing
    end
    
    # Associate capabilities with role
    role
    |> Repo.preload(:capabilities)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:capabilities, [capability1])
    |> Repo.update!()

    # Assign role to user
    {:ok, user} = user
      |> User.role_changeset(%{role_id: role.id})
      |> Repo.update()

    # Preload role and capabilities
    user = user |> Repo.preload(role: :capabilities)

    conn = conn
      |> put_req_header("accept", "application/json")
      |> assign(:current_user, user)  # Mock the current_user assignment from APIAuthPlug

    {:ok, conn: conn, user: user, role: role}
  end

  describe "APIAuthorizePlug initialization" do
    test "init/1 accepts string capability" do
      result = APIAuthorizePlug.init("any_capability")
      assert result == %{capability: "any_capability"}
    end

    test "init/1 accepts atom capability" do
      result = APIAuthorizePlug.init(:any_capability)
      assert result == %{capability: :any_capability}
    end

    test "init/1 accepts options keyword list" do
      result = APIAuthorizePlug.init([capability: "any_capability"])
      assert result == %{capability: "any_capability"}
    end

    test "init/1 handles empty list as auth-only mode" do
      result = APIAuthorizePlug.init([])
      assert result == %{capability: nil}
    end
    
    test "init/1 raises error for invalid input" do
      assert_raise ArgumentError, fn -> APIAuthorizePlug.init(123) end
    end
  end

  describe "APIAuthorizePlug authorization" do
    test "allows requests when user has required capability", %{conn: conn, user: user} do
      # Pass the specific capability name created in the setup
      capability_name = hd(user.role.capabilities).name
      
      # Call the plug with a capability the user has
      conn = APIAuthorizePlug.call(conn, %{capability: capability_name})

      # Verify the connection is not halted
      refute conn.halted
    end
    
    test "allows authenticated requests in auth-only mode", %{conn: conn} do
      # Call the plug with no capability requirement
      conn = APIAuthorizePlug.call(conn, %{capability: nil})
      
      # Verify the connection is not halted
      refute conn.halted
    end

    test "rejects requests when user doesn't have required capability", %{conn: conn} do
      # Call the plug with a capability the user doesn't have
      conn = APIAuthorizePlug.call(conn, %{capability: "missing_capability"})

      # Verify the connection is halted with a forbidden status
      assert conn.halted
      assert conn.status == 403
      assert Jason.decode!(conn.resp_body)["error"] =~ "Insufficient permissions"
    end

    test "rejects requests when no user is assigned", %{conn: conn} do
      # Remove the current_user assignment
      conn = conn |> assign(:current_user, nil)

      # Call the plug
      conn = APIAuthorizePlug.call(conn, %{capability: "test_capability"})

      # Verify the connection is halted with an unauthorized status
      assert conn.halted
      assert conn.status == 401
      assert Jason.decode!(conn.resp_body)["error"] =~ "Authentication required"
    end

    test "has_capability?/2 delegates to AuthHelpers", %{user: user} do
      # Get the actual capability name from the user's role
      capability_name = hd(user.role.capabilities).name
      
      # Test the delegation - should match AuthHelpers behavior
      assert APIAuthorizePlug.has_capability?(user, capability_name) == true
      assert APIAuthorizePlug.has_capability?(user, "non_existent") == false
    end
  end
end