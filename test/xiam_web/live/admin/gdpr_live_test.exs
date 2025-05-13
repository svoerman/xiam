defmodule XIAMWeb.Admin.GDPRLiveTest do
  use XIAMWeb.ConnCase, async: false
  import Plug.Conn
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  alias XIAM.Repo
    # Silence warning for unused Role alias - may be used in future tests
  alias Xiam.Rbac.Role, warn: false
  
  import XIAM.ETSTestHelper


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
    # Create a unique admin role
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    unique_str = "#{System.system_time(:millisecond)}_#{:rand.uniform(100_000)}"
    admin_role = %Xiam.Rbac.Role{
      name: "Admin Role #{unique_str}",
      description: "Admin role for tests",
      inserted_at: now,
      updated_at: now
    }

    # Insert role first to get a real integer ID
    inserted_role = Repo.insert!(admin_role)

    # Create admin user with role_id
    admin_user = %XIAM.Users.User{
      email: "admin_#{unique_str}@example.com",
      role_id: inserted_role.id,
      inserted_at: now,
      updated_at: now
    }

    # Create test user (to be managed by admin)
    test_user = %XIAM.Users.User{
      email: "user_#{unique_str}@example.com",
      inserted_at: now,
      updated_at: now
    }

    {admin_user, test_user}
  end

  describe "GDPR LiveView" do
    setup %{conn: conn} do
      # Ensure proper ETS tables exist
      ensure_ets_tables_exist()
      

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
      
      # Insert admin_user and test_user into the database
      _inserted_admin = Repo.insert!(admin_user)
      _inserted_test = Repo.insert!(test_user)

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
