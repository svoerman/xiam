defmodule XIAMWeb.Plugs.APIAuthorizePlugTest do
  use XIAMWeb.ConnCase

  alias XIAMWeb.Plugs.APIAuthorizePlug
  alias XIAM.Users.User
  alias Xiam.Rbac.{Role, Capability}
  alias XIAM.Repo

  setup %{conn: conn} do
    # Create a test user
    {:ok, user} = %User{}
      |> User.pow_changeset(%{
        email: "api_authorize_test@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Repo.insert()

    # Create a role with test capabilities
    {:ok, role} = %Role{
      name: "Authorize Test Role",
      description: "Role for testing authorization"
    }
    |> Repo.insert()

    # Create a product for capabilities
    {:ok, product} = %Xiam.Rbac.Product{
      product_name: "API Auth Test Product",
      description: "Product for testing API auth"
    }
    |> Repo.insert()
    
    # Create test capabilities
    {:ok, capability1} = %Capability{
      name: "test_capability",
      description: "Test capability",
      product_id: product.id
    }
    |> Repo.insert()
    
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
      result = APIAuthorizePlug.init("test_capability")
      assert result == %{capability: "test_capability"}
    end

    test "init/1 accepts atom capability" do
      result = APIAuthorizePlug.init(:test_capability)
      assert result == %{capability: :test_capability}
    end

    test "init/1 accepts options keyword list" do
      result = APIAuthorizePlug.init([capability: "test_capability"])
      assert result == %{capability: "test_capability"}
    end

    test "init/1 raises error for invalid input" do
      assert_raise ArgumentError, fn -> APIAuthorizePlug.init(123) end
      assert_raise ArgumentError, fn -> APIAuthorizePlug.init([]) end
    end
  end

  describe "APIAuthorizePlug authorization" do
    test "allows requests when user has required capability", %{conn: conn} do
      # Call the plug with a capability the user has
      conn = APIAuthorizePlug.call(conn, %{capability: "test_capability"})

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
      # Test the delegation - should match AuthHelpers behavior
      assert APIAuthorizePlug.has_capability?(user, "test_capability") == true
      assert APIAuthorizePlug.has_capability?(user, "non_existent") == false
    end
  end
end