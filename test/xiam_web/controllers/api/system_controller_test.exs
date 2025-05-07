defmodule XIAMWeb.API.SystemControllerTest do
  use XIAMWeb.ConnCase, async: false
  
  # Import the ETSTestHelper to ensure proper test environment
  import XIAM.ETSTestHelper

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
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Use safely_execute_ets_operation for API requests
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        conn = conn
          |> put_req_header("accept", "application/json")
          |> get(~p"/api/system/health") # Use the old endpoint path for backward compatibility

        # Verify behavior - focus on response structure
        response = json_response(conn, 200)
        assert response["status"] == "ok", "Expected health status to be 'ok'"
        assert response["version"] != nil, "Expected version to be present"
        assert response["timestamp"] != nil, "Expected timestamp to be present"

        # Verify timestamp format (ISO8601)
        timestamp = response["timestamp"]
        assert String.match?(timestamp, ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/), "Expected ISO8601 timestamp format"
      end)
    end
  end

  describe "status/2" do
    test "returns detailed health information when authenticated", %{authed_conn: conn} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Use safely_execute_ets_operation with mocking for API requests
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
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
              system: %{
                status: :ok,
                memory: {
                  4096, # Total memory (MB)
                  2048, # Used memory (MB)
                  50    # Percentage used
                },
                cpu: {
                  4,    # Number of cores
                  25    # CPU usage percentage
                }
              }
            }
          end
        ] do
          conn = get(conn, ~p"/api/system/status")
          
          # Verify behavior - focus on response structure and content
          response = json_response(conn, 200)
          
          # Check overall status
          assert response["status"] == "ok", "Expected system status to be 'ok'"
          
          # Check database section
          assert %{"database" => database} = response
          assert database["connected"] == true, "Expected database to be connected"
          assert database["user_count"] == 10, "Expected user_count to match mock data"
          assert database["version"] == "PostgreSQL 15.3", "Expected database version to match mock data"
          
          # Check application section
          assert %{"application" => app} = response
          assert app["version"] == "0.1.0", "Expected app version to match mock data"
          assert app["uptime"] == 3600, "Expected uptime to match mock data"
          assert app["environment"] == "test", "Expected environment to match mock data"
          
          # Check system section
          assert %{"system" => system} = response
          assert system["memory"]["total"] == 4096, "Expected memory total to match mock data"
          assert system["memory"]["used"] == 2048, "Expected memory used to match mock data"
          assert system["memory"]["percentage"] == 50, "Expected memory percentage to match mock data"
          assert system["cpu"]["cores"] == 4, "Expected CPU cores to match mock data"
          assert system["cpu"]["usage"] == 25, "Expected CPU usage to match mock data"
        end
      end)
    end

    test "requires authentication", %{conn: conn} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Use safely_execute_ets_operation for API requests
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        # Test the endpoint without authentication
        conn = conn
          |> put_req_header("accept", "application/json")
          |> get(~p"/api/system/status")
        
        # Verify behavior - unauthenticated requests should be rejected
        response = json_response(conn, 401)
        assert response["error"] == "Unauthorized", "Expected unauthorized error for unauthenticated request"
      end)
    end

    test "respects capability check", %{conn: conn} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Create a user without capabilities using safely_execute_db_operation
      {_regular_user, regular_token} = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        # Get user without capabilities
        {:ok, regular_user} = User.pow_changeset(%User{}, %{
          email: "noperms_#{System.system_time(:millisecond)}_#{:rand.uniform(100_000)}@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        }) |> Repo.insert()

        # Generate token for user without capabilities
        {:ok, regular_token, _claims} = JWT.generate_token(regular_user)
        
        {regular_user, regular_token}
      end)
      
      # Use safely_execute_ets_operation for API requests
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        # Set up connection with regular user token
        conn = conn
          |> put_req_header("accept", "application/json")
          |> put_req_header("content-type", "application/json")
          |> put_req_header("authorization", "Bearer #{regular_token}")

        # Make the request
        conn = get(conn, ~p"/api/system/status")
        
        # Verify behavior - should reject users without the required capability
        response = json_response(conn, 403)
        assert response["error"] == "Forbidden", "Expected forbidden error for unauthorized user"
      end)
    end
  end
end
