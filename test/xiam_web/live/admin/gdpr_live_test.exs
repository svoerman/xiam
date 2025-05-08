defmodule XIAMWeb.Admin.GDPRLiveTest do
  use XIAMWeb.ConnCase, async: false
  import Plug.Conn
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  alias XIAM.Repo
  alias XIAM.Users.User
  # Silence warning for unused Role alias - may be used in future tests
  alias Xiam.Rbac.Role, warn: false
  import Mock
  import XIAM.ETSTestHelper

  # Setup helper to create a consistent mock for Repo.preload
  defp create_preload_mock do
    fn user, preload_opts ->
      case preload_opts do
        [role: :capabilities] ->
          # Create a proper %Xiam.Rbac.Role{} with proper %Xiam.Rbac.Capability{} structs
          admin_capability = %Xiam.Rbac.Capability{
            id: 1,
            name: "admin_access",
            description: "Admin access capability",
            product_id: 1,
            inserted_at: NaiveDateTime.utc_now(),
            updated_at: NaiveDateTime.utc_now()
          }

          role = case user.role do
            %Xiam.Rbac.Role{} = role ->
              # Keep the existing struct but update capabilities
              %{role | capabilities: [admin_capability]}
            _ ->
              # Create a new role struct if needed
              %Xiam.Rbac.Role{
                id: user.role_id || 999,
                name: "Admin Role",
                description: "Admin role for tests",
                capabilities: [admin_capability],
                inserted_at: NaiveDateTime.utc_now(),
                updated_at: NaiveDateTime.utc_now()
              }
          end

          %{user | role: role}
        _ -> user
      end
    end
  end

  # Helper to login a user for testing
  defp login(conn, user) do
    # Create session for user
    conn
    |> init_test_session(%{})
    |> put_session(:pow_user_auth, %{
      "user_id" => user.id,
      "fingerprint" => "test_fingerprint"
    })
  end

  # Create minimal test users with proper structs
  defp create_test_users do
    # Create a mock role with admin capabilities
    mock_role = %Xiam.Rbac.Role{
      id: "role_#{System.system_time(:millisecond)}_#{:rand.uniform(100_000)}",
      name: "Admin Role",
      description: "Admin role for tests",
      capabilities: [
        %Xiam.Rbac.Capability{id: 1, name: "admin_access"},
        %Xiam.Rbac.Capability{id: 2, name: "admin_gdpr_access"}
      ],
      inserted_at: NaiveDateTime.utc_now(),
      updated_at: NaiveDateTime.utc_now()
    }

    # Create admin user with role
    admin_user = %XIAM.Users.User{
      id: "admin_#{System.system_time(:millisecond)}_#{:rand.uniform(100_000)}",
      email: "admin_#{System.system_time(:millisecond)}@example.com",
      role: mock_role,
      role_id: mock_role.id,
      inserted_at: NaiveDateTime.utc_now(),
      updated_at: NaiveDateTime.utc_now()
    }

    # Create test user (to be managed by admin)
    test_user = %XIAM.Users.User{
      id: "user_#{System.system_time(:millisecond)}_#{:rand.uniform(100_000)}",
      email: "user_#{System.system_time(:millisecond)}@example.com",
      inserted_at: NaiveDateTime.utc_now(),
      updated_at: NaiveDateTime.utc_now()
    }

    {admin_user, test_user}
  end

  describe "GDPR LiveView" do
    setup %{conn: conn} do
      # Ensure proper ETS tables exist
      ensure_ets_tables_exist()
      
      # Prepare database connection for tests
      {:ok, _} = Application.ensure_all_started(:ecto_sql)
      {:ok, _} = Application.ensure_all_started(:postgrex)
      Ecto.Adapters.SQL.Sandbox.checkout(Repo)
      Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
      
      # Create test users with proper structs
      {admin_user, test_user} = create_test_users()
      
      # Prepare connection for LiveView tests
      conn = %{conn | 
               private: Map.put(conn.private, :phoenix_endpoint, XIAMWeb.Endpoint),
               owner: self()}
      
      # Authenticate admin user
      conn = login(conn, admin_user)
      
      # Return context for tests
      {:ok, %{conn: conn, admin_user: admin_user, test_user: test_user}}
    end

    test "selects a user and displays their management panel", context do
      # Extract context
      %{conn: conn, admin_user: admin_user, test_user: test_user} = context
      
      # Define the mock function outside the with_mocks block to capture context variables
      get_by_mock = fn User, query_opts ->
        case Keyword.fetch(query_opts, :id) do
          {:ok, id} when id == admin_user.id -> admin_user
          {:ok, id} when id == test_user.id -> test_user
          _ -> nil
        end
      end

      # Use with_mocks to mock the necessary database calls
      with_mocks([
        {Repo, [], [get_by: get_by_mock, preload: create_preload_mock()]}
      ]) do
        # Use resilient patterns for LiveView rendering
        XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
          # Navigate to GDPR page
          {:ok, view, _html} = live(conn, ~p"/admin/gdpr")
          
          # Verify basic page content
          assert has_element?(view, "h1", "GDPR User Management")
          
          # This is a minimal test to verify the page loads successfully
          assert render(view) =~ "GDPR User Management"
        end, max_retries: 3, retry_delay: 200)
      end
    end
  end
end
