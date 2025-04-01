defmodule XIAMWeb.Plugs.AuthHelpersTest do
  use XIAMWeb.ConnCase

  alias XIAMWeb.Plugs.AuthHelpers
  alias XIAM.Users.User
  alias Xiam.Rbac.{Role, Capability}
  alias XIAM.Auth.JWT
  alias XIAM.Repo

  setup do
    # Create a test user with admin capability
    {:ok, user} = %User{}
      |> User.pow_changeset(%{
        email: "auth_helper_test@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Repo.insert()

    # Create a role with capabilities
    {:ok, role} = %Role{
      name: "Auth Test Role",
      description: "Role for testing auth helpers"
    }
    |> Repo.insert()

    # Create a product for capabilities
    {:ok, product} = %Xiam.Rbac.Product{
      product_name: "Auth Test Product",
      description: "Product for testing auth"
    }
    |> Repo.insert()
    
    # Create an admin capability
    {:ok, admin_capability} = %Capability{
      name: "admin_access",
      description: "Admin access capability",
      product_id: product.id
    }
    |> Repo.insert()

    # Create a test capability
    {:ok, test_capability} = %Capability{
      name: "test_capability",
      description: "Test capability",
      product_id: product.id
    }
    |> Repo.insert()
    
    # Associate capabilities with role
    role
    |> Repo.preload(:capabilities)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:capabilities, [admin_capability, test_capability])
    |> Repo.update!()

    # Assign role to user
    {:ok, user_with_role} = user
      |> User.role_changeset(%{role_id: role.id})
      |> Repo.update()

    # Create a connection for tests
    conn = build_conn()
      |> put_req_header("accept", "application/json")

    {:ok, conn: conn, user: user_with_role, role: role}
  end

  describe "auth helpers" do
    test "extract_token/1 extracts token from Authorization header", %{conn: conn, user: user} do
      # Generate a valid token
      {:ok, token, _claims} = JWT.generate_token(user)

      # Test with Bearer token
      conn_with_token = conn
        |> put_req_header("authorization", "Bearer #{token}")

      assert {:ok, extracted_token} = AuthHelpers.extract_token(conn_with_token)
      assert extracted_token == token

      # Test with lowercase bearer
      conn_with_lowercase = conn
        |> put_req_header("authorization", "bearer #{token}")

      assert {:ok, extracted_token} = AuthHelpers.extract_token(conn_with_lowercase)
      assert extracted_token == token
    end

    test "extract_token/1 handles missing or invalid Authorization header", %{conn: conn} do
      # Test with missing header
      assert {:error, :token_not_found} = AuthHelpers.extract_token(conn)

      # Test with invalid format
      conn_with_invalid = conn
        |> put_req_header("authorization", "InvalidFormat token123")

      assert {:error, :invalid_token_format} = AuthHelpers.extract_token(conn_with_invalid)
    end

    test "verify_jwt_token/1 verifies a valid token", %{user: user} do
      # Generate a valid token
      {:ok, token, _claims} = JWT.generate_token(user)

      # Verify the token
      assert {:ok, verified_user, claims} = AuthHelpers.verify_jwt_token(token)
      assert verified_user.id == user.id
      assert to_string(claims["sub"]) == to_string(user.id)
    end

    test "verify_jwt_token/1 rejects an invalid token" do
      assert {:error, _reason} = AuthHelpers.verify_jwt_token("invalid_token")
    end

    test "has_capability?/2 checks for user capabilities", %{user: user} do
      user = Repo.preload(user, role: :capabilities)

      # Test with existing capability
      assert AuthHelpers.has_capability?(user, "test_capability") == true

      # Test with non-existent capability
      assert AuthHelpers.has_capability?(user, "non_existent_capability") == false

      # Test with nil user
      assert AuthHelpers.has_capability?(nil, "any_capability") == false
    end

    test "has_admin_privileges?/1 checks for admin capability", %{user: user} do
      user = Repo.preload(user, role: :capabilities)

      # User has admin capability
      assert AuthHelpers.has_admin_privileges?(user) == true

      # Test with nil user
      assert AuthHelpers.has_admin_privileges?(nil) == false

      # Create a user without admin privileges
      {:ok, non_admin_user} = %User{}
        |> User.pow_changeset(%{
          email: "non_admin@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })
        |> Repo.insert()

      # Create a role without admin capability
      {:ok, non_admin_role} = %Role{
        name: "Non-Admin Role",
        description: "Role without admin access"
      }
      |> Repo.insert()

      # Assign role to user
      {:ok, non_admin_user} = non_admin_user
        |> User.role_changeset(%{role_id: non_admin_role.id})
        |> Repo.update()

      non_admin_user = Repo.preload(non_admin_user, role: :capabilities)
      assert AuthHelpers.has_admin_privileges?(non_admin_user) == false
    end

    test "unauthorized_response/2 returns proper response", %{conn: conn} do
      reason = "Test unauthorized reason"
      
      conn = AuthHelpers.unauthorized_response(conn, reason)
      
      assert conn.status == 401
      assert conn.halted == true
      assert Jason.decode!(conn.resp_body)["error"] == reason
    end

    test "forbidden_response/2 returns proper response", %{conn: conn} do
      reason = "Test forbidden reason"
      
      conn = AuthHelpers.forbidden_response(conn, reason)
      
      assert conn.status == 403
      assert conn.halted == true
      assert Jason.decode!(conn.resp_body)["error"] == reason
    end
  end
end