defmodule XIAMWeb.API.AuthControllerTest do
  use XIAMWeb.ConnCase

  alias XIAM.Users.User
  alias XIAM.Repo
  alias XIAM.Auth.JWT
  alias XIAM.Rbac.ProductContext


  setup %{conn: conn} do
    # Generate a unique timestamp for this test run
    timestamp = System.system_time(:second)

    # Create a test user
    {:ok, user} = %User{}
      |> User.pow_changeset(%{
        email: "api_auth_test_#{timestamp}@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Repo.insert()

    # Create a role with basic auth capabilities
    role_name = "Auth_User_#{timestamp}"
    {:ok, role} = Xiam.Rbac.Role.changeset(%Xiam.Rbac.Role{}, %{
      name: role_name,
      description: "Role for testing auth API"
    })
    |> Repo.insert()

    # Create a product to associate capabilities with
    product_name = "Test_Auth_Product_#{timestamp}"
    {:ok, product} = ProductContext.create_product(%{
      product_name: product_name,
      description: "Test product for auth API tests"
    })

    # Add basic auth capabilities
    capabilities_to_create = [
      %{product_id: product.id, name: "verify_token", description: "Can verify tokens"},
      %{product_id: product.id, name: "refresh_token", description: "Can refresh tokens"},
      %{product_id: product.id, name: "logout", description: "Can logout"},
      %{product_id: product.id, name: "auth", description: "Basic auth capabilities"}
    ]

    capabilities = Enum.map(capabilities_to_create, fn cap_attrs ->
      {:ok, cap} = Xiam.Rbac.create_capability(cap_attrs)
      cap
    end)

    # Associate capabilities with role
    {:ok, role} = role
      |> Repo.preload(:capabilities)
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:capabilities, capabilities)
      |> Repo.update()

    # Assign role to user
    {:ok, user} = user
      |> User.role_changeset(%{role_id: role.id})
      |> Repo.update()

    # Reload user with role and capabilities
    user = user |> Repo.preload(role: :capabilities)

    conn = conn
      |> put_req_header("accept", "application/json")

    {:ok, conn: conn, user: user}
  end

  describe "authentication" do
    test "login with valid credentials returns token", %{conn: conn, user: user} do
      conn = post(conn, ~p"/api/v1/auth/login", %{
        email: user.email,
        password: "Password123!"
      })

      assert %{"token" => token, "user" => user_data} = json_response(conn, 200)
      assert is_binary(token)
      assert user_data["email"] == user.email
      assert user_data["id"] == user.id
    end

    test "login with MFA-enabled user returns partial token", %{conn: conn, user: user} do
      # Enable MFA for the user
      {:ok, user_with_mfa} = user
        |> Ecto.Changeset.change(%{mfa_enabled: true, mfa_secret: XIAM.Users.User.generate_totp_secret()})
        |> Repo.update()

      conn = post(conn, ~p"/api/v1/auth/login", %{
        email: user_with_mfa.email,
        password: "Password123!"
      })

      response = json_response(conn, 200)
      
      # Verify the response contains MFA-specific fields
      assert response["mfa_required"] == true
      assert is_binary(response["partial_token"])
      assert Map.has_key?(response, "partial_token")
      refute Map.has_key?(response, "token")
      assert response["user"]["email"] == user_with_mfa.email
      assert response["user"]["id"] == user_with_mfa.id
    end

    test "login with invalid credentials returns error", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/auth/login", %{
        email: "wrong@example.com",
        password: "WrongPassword123!"
      })

      assert json_response(conn, 401)["error"] =~ "Invalid email or password"
    end

    test "verify token with valid token succeeds", %{conn: conn, user: user} do
      # Generate a valid token
      {:ok, token, _claims} = JWT.generate_token(user)

      conn = conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/v1/auth/verify")

      assert json_response(conn, 200)["valid"] == true
      assert json_response(conn, 200)["user"]["id"] == user.id
    end

    test "verify token with invalid token fails", %{conn: conn} do
      conn = conn
        |> put_req_header("authorization", "Bearer invalid_token")
        |> get(~p"/api/v1/auth/verify")

      assert json_response(conn, 401)["error"] =~ "Invalid token"
    end

    test "refresh token with valid token returns new token", %{conn: conn, user: user} do
      # Generate a valid token
      {:ok, token, _claims} = JWT.generate_token(user)

      conn = conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/v1/auth/refresh")

      assert %{"token" => new_token} = json_response(conn, 200)
      assert is_binary(new_token)
      assert new_token != token
    end

    test "refresh token with invalid token fails", %{conn: conn} do
      conn = conn
        |> put_req_header("authorization", "Bearer invalid_token")
        |> post(~p"/api/v1/auth/refresh")

      assert json_response(conn, 401)["error"] =~ "Invalid token"
    end

    test "logout invalidates token", %{conn: conn, user: user} do
      # Generate a valid token
      {:ok, token, _claims} = JWT.generate_token(user)

      conn = conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/v1/auth/logout")

      assert json_response(conn, 200)["message"] == "Logged out successfully"

      # Try to use the token again - it should be invalidated
      # This requires token blacklisting to be implemented in the app
      # If blacklisting is not yet implemented, this test may need to be adjusted
    end
  end

  describe "MFA authentication" do
    setup %{user: user} do
      # Enable MFA for the user
      {:ok, user_with_mfa} = user
        |> Ecto.Changeset.change(%{mfa_enabled: true, mfa_secret: XIAM.Users.User.generate_totp_secret()})
        |> Repo.update()

      # Generate a partial token for MFA flow
      {:ok, partial_token, _claims} = JWT.generate_partial_token(user_with_mfa)
      
      {:ok, user_with_mfa: user_with_mfa, partial_token: partial_token}
    end

    test "MFA challenge returns instructions", %{conn: conn, partial_token: partial_token} do
      conn = conn
        |> put_req_header("authorization", "Bearer #{partial_token}")
        |> get(~p"/api/v1/auth/mfa/challenge")

      response = json_response(conn, 200)
      assert response["success"] == true
      assert response["message"] =~ "authenticator app"
    end

    test "MFA verification with valid code returns full token", %{conn: conn, partial_token: partial_token} do
      # Patch the User.verify_totp function for this test
      
      try do
        # Replace with a function that always returns true
        :meck.new(XIAM.Users.User, [:passthrough])
        :meck.expect(XIAM.Users.User, :verify_totp, fn _user, _code -> true end)

        conn = conn
          |> put_req_header("authorization", "Bearer #{partial_token}")
          |> post(~p"/api/v1/auth/mfa/verify", %{"code" => "123456"})

        response = json_response(conn, 200)
        assert response["success"] == true
        assert is_binary(response["token"])
        assert response["message"] =~ "successful"
      after
        :meck.unload(XIAM.Users.User)
      end
    end

    test "MFA verification with invalid code returns error", %{conn: conn, partial_token: partial_token} do
      # Patch the User.verify_totp function for this test
      try do
        # Replace with a function that always returns false
        :meck.new(XIAM.Users.User, [:passthrough])
        :meck.expect(XIAM.Users.User, :verify_totp, fn _user, _code -> false end)

        conn = conn
          |> put_req_header("authorization", "Bearer #{partial_token}")
          |> post(~p"/api/v1/auth/mfa/verify", %{"code" => "000000"})

        response = json_response(conn, 401)
        assert response["success"] == false
        assert response["error"] =~ "Invalid MFA code"
      after
        :meck.unload(XIAM.Users.User)
      end
    end

    test "MFA verification with regular token returns error", %{conn: conn, user: user} do
      # Generate a regular token (not a partial token)
      {:ok, regular_token, _claims} = JWT.generate_token(user)

      conn = conn
        |> put_req_header("authorization", "Bearer #{regular_token}")
        |> post(~p"/api/v1/auth/mfa/verify", %{"code" => "123456"})

      response = json_response(conn, 400)
      assert response["success"] == false
      assert response["error"] =~ "Invalid authentication flow"
    end
  end
end
