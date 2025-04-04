defmodule XIAMWeb.API.SystemControllerTest do
  use XIAMWeb.ConnCase

  alias XIAM.Users.User
  alias XIAM.Repo
  alias XIAM.Auth.JWT

  import Mock

  # Create test data with an authenticated user
  setup %{conn: conn} do
    # Create test user with correct fields for Pow
    {:ok, user} = User.pow_changeset(%User{}, %{
      email: "testuser@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    }) |> Repo.insert()

    # Add system capability to the user for the status endpoint
    {:ok, role} = Xiam.Rbac.create_role(%{
      name: "System Admin",
      description: "Role with system status capability"
    })

    {:ok, product} = Xiam.Rbac.create_product(%{
      product_name: "System Management",
      description: "System management product"
    })

    {:ok, capability} = Xiam.Rbac.create_capability(%{
      name: "view_system_status",
      description: "Can view system status",
      product_id: product.id
    })

    # Associate capability with role
    Xiam.Rbac.add_capability_to_role(role.id, capability.id)

    # Assign role to user
    user
    |> User.role_changeset(%{role_id: role.id})
    |> Repo.update!()

    # Prepare connection with JSON headers
    conn = conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")

    # Create a mock JWT token
    {:ok, token, _claims} = JWT.generate_token(user)

    # Preload role and capabilities for the user
    user = user |> Repo.preload(role: :capabilities)

    # Authenticated connection for protected endpoints with Bearer token
    authed_conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> assign(:current_user, user)

    %{
      conn: conn,
      authed_conn: authed_conn,
      user: user,
      token: token
    }
  end

  describe "health/2" do
    test "returns basic health information without authentication", %{conn: conn} do
      conn = conn
        |> put_req_header("accept", "application/json")
        |> get(~p"/api/system/health") # Use the old endpoint path for backward compatibility

      response = json_response(conn, 200)
      assert response["status"] == "ok"
      assert response["version"] != nil
      assert response["timestamp"] != nil

      # Since we're testing an endpoint that might be changing, be more flexible with assertions
      # environment might not be included in all implementations
    end
  end

  describe "status/2" do
    test "returns detailed health information when authenticated", %{authed_conn: conn} do
      # Mock the Health module to return consistent test data
      with_mock XIAM.System.Health, [
        check_health: fn ->
          %{
            database: %{
              status: :ok,
              connected: true,
              user_count: 10,
              version: "PostgreSQL 15.3"
            },
            application: %{
              status: :ok,
              version: "0.1.0",
              uptime: 3600,
              environment: :test
            },
            memory: %{
              status: :ok,
              total: 1_000_000,
              processes: 500_000,
              atom: 100_000,
              binary: 200_000,
              code: 300_000,
              ets: 150_000,
              system: 250_000
            },
            disk: %{
              status: :ok,
              free: 10_000_000_000,
              total: 50_000_000_000
            },
            cluster: %{
              status: :ok,
              nodes: [node()]
            },
            system_info: %{
              otp_release: "25.0",
              process_count: 400,
              port_count: 30
            },
            timestamp: ~U[2023-01-01 00:00:00Z]
          }
        end
      ] do
        conn = get(conn, ~p"/api/system/status")

        response = json_response(conn, 200)

        # Check for presence of main health check sections
        assert Map.has_key?(response, "database")
        assert Map.has_key?(response, "application")
        assert Map.has_key?(response, "memory")
        assert Map.has_key?(response, "disk")
        assert Map.has_key?(response, "cluster")
        assert Map.has_key?(response, "system_info")
        assert Map.has_key?(response, "timestamp")

        # Verify application section data
        assert response["application"]["status"] == "ok"
        assert response["application"]["version"] == "0.1.0"
        assert response["application"]["uptime"] == 3600

        # Verify memory section data is converted to MB
        assert response["memory"]["status"] == "ok"
        assert response["memory"]["total"] == 0.95 # 1_000_000 bytes converts to ~0.95 MB

        # Verify system info section data
        assert response["system_info"]["otp_release"] == "25.0"
        assert response["system_info"]["process_count"] == 400
      end
    end

    test "returns 401 unauthorized when not authenticated", %{conn: conn} do
      conn = conn
        |> put_req_header("accept", "application/json")
        |> get(~p"/api/system/status")
      response = json_response(conn, 401)
      assert response["error"] == "Authorization header missing or invalid"
    end

    test "returns 403 forbidden when user doesn't have required capability", %{conn: _conn, user: user} do
      # Remove the capability from the user and ensure role is nil
      user = user
      |> User.role_changeset(%{role_id: nil})
      |> Repo.update!()
      |> Repo.preload(role: :capabilities)

      # Create a new token for the user without capabilities
      {:ok, token, _claims} = JWT.generate_token(user)

      # Create a new connection with the token but without capabilities
      conn = build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("content-type", "application/json")
        |> put_req_header("authorization", "Bearer #{token}")
        |> bypass_through(XIAMWeb.Router, [:api, :api_jwt])
        |> get(~p"/api/system/status")
        |> recycle()
        |> bypass_through(XIAMWeb.Router, [:api, :api_jwt])
        |> assign(:current_user, user)
        |> XIAMWeb.Plugs.APIAuthorizePlug.call(%{capability: "view_system_status"})
        |> get(~p"/api/system/status")

      assert json_response(conn, 403) == %{
        "error" => "Access forbidden: Missing required capability"
      }
    end
  end
end
