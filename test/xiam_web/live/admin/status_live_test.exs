defmodule XIAMWeb.Admin.StatusLiveTest do
  use XIAMWeb.ConnCase

  import Phoenix.LiveViewTest
  alias XIAM.Users.User
  alias XIAM.Repo

  # Helper for test authentication
  def create_admin_user() do
    # Create a user
    {:ok, user} = %User{}
      |> User.pow_changeset(%{
        email: "status_admin_user@example.com", 
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Repo.insert()

    # Create a role with admin capability
    {:ok, role} = %Xiam.Rbac.Role{
      name: "Status Admin Role",
      description: "Role with admin access"
    }
    |> Repo.insert()

    # Create a product for capabilities
    {:ok, product} = %Xiam.Rbac.Product{
      product_name: "Status Test Product",
      description: "Product for testing status admin access"
    }
    |> Repo.insert()
    
    # Add admin capabilities
    {:ok, status_capability} = %Xiam.Rbac.Capability{
      name: "admin_status_access",
      description: "Admin status access capability",
      product_id: product.id
    }
    |> Repo.insert()
    
    # Add generic admin access capability (required by AdminAuthPlug)
    {:ok, admin_capability} = %Xiam.Rbac.Capability{
      name: "admin_access",
      description: "General admin access capability",
      product_id: product.id
    }
    |> Repo.insert()
    
    # Associate capabilities with role
    role
    |> Repo.preload(:capabilities)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:capabilities, [status_capability, admin_capability])
    |> Repo.update!()

    # Assign role to user
    {:ok, user} = user
      |> User.role_changeset(%{role_id: role.id})
      |> Repo.update()

    # Return user with preloaded role and capabilities
    user |> Repo.preload(role: :capabilities)
  end

  defp login(conn, user) do
    # Using Pow's test helpers with explicit config
    pow_config = [otp_app: :xiam]
    conn
    |> Pow.Plug.assign_current_user(user, pow_config)
  end

  setup %{conn: conn} do
    # Create admin user
    user = create_admin_user()

    # Authenticate connection
    conn = login(conn, user)

    # Return authenticated connection and user
    {:ok, conn: conn, user: user}
  end

  describe "Status LiveView" do
    test "mounts successfully", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/status")

      # Verify page title is set correctly
      assert html =~ "System Status"
      assert html =~ "Monitor system health, cluster status, and performance metrics"
    end

    test "displays system info sections", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/status")

      # Verify all main sections exist
      assert has_element?(view, "h3", "System")
      assert has_element?(view, "h3", "Database")
      assert has_element?(view, "h3", "Cluster")
      assert has_element?(view, "h3", "Background Jobs")
      
      # Verify detailed sections
      assert has_element?(view, "h3", "Cluster Nodes")
      assert has_element?(view, "h3", "Memory Usage")
      assert has_element?(view, "h3", "Job Queues")
      assert has_element?(view, "h3", "System Information")
    end

    test "displays system metrics", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/status")

      # Verify system metrics are displayed
      assert has_element?(view, "div", "CPU Usage")
      assert has_element?(view, "div", "Memory")
      assert has_element?(view, "div", "Processes")
      assert has_element?(view, "div", "Uptime")
      
      # Verify memory sections
      assert has_element?(view, "span", "Process Memory")
      assert has_element?(view, "span", "Atom Memory")
      assert has_element?(view, "span", "Binary Memory")
      assert has_element?(view, "span", "Code Memory")
      assert has_element?(view, "span", "ETS Memory")
    end

    test "displays database metrics", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/status")

      # Verify database metrics are displayed
      assert has_element?(view, "div", "Pool Size")
      assert has_element?(view, "div", "Active Connections")
      assert has_element?(view, "div", "Total Queries")
      assert has_element?(view, "div", "Avg Query Time")
    end

    test "displays cluster metrics", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/status")

      # Verify cluster metrics are displayed
      assert has_element?(view, "div", "Nodes")
      assert has_element?(view, "div", "Connected")
      assert has_element?(view, "div", "Node Distribution")
      
      # Verify cluster nodes table headers
      assert has_element?(view, "th", "Node")
      assert has_element?(view, "th", "Status")
      assert has_element?(view, "th", "Memory")
      assert has_element?(view, "th", "Processes")
      assert has_element?(view, "th", "Uptime")
    end

    test "displays background job metrics", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/status")

      # Verify job metrics are displayed
      assert has_element?(view, "div", "Completed")
      assert has_element?(view, "div", "Pending")
      assert has_element?(view, "div", "Failed")
      assert has_element?(view, "div", "Cancelled")
      
      # Verify job queues table headers
      assert has_element?(view, "th", "Queue")
      assert has_element?(view, "th", "Workers")
      assert has_element?(view, "th", "Status")
    end

    test "displays system information", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/status")

      # Verify system information is displayed
      assert has_element?(view, "dt", "BEAM Version")
      assert has_element?(view, "dt", "Elixir Version")
      assert has_element?(view, "dt", "Node Name")
      assert has_element?(view, "dt", "System Architecture")
      assert has_element?(view, "dt", "Process Limit")
      assert has_element?(view, "dt", "Atom Limit")
      assert has_element?(view, "dt", "Scheduler Count")
      assert has_element?(view, "dt", "OTP Release")
    end

    test "renders node distribution elements", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/status")

      # Verify node distribution-related elements are in the page
      assert html =~ "Node Distribution"
      assert html =~ "Cluster Nodes"
      assert html =~ "phx-click=\"show_node_details\""
    end

    test "renders memory usage elements", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/status")

      # Verify memory-related elements are in the page
      assert html =~ "Memory Usage"
      assert html =~ "Process Memory"
      assert html =~ "Atom Memory" 
      assert html =~ "Binary Memory"
      assert html =~ "Code Memory"
      assert html =~ "ETS Memory"
    end

    test "handles theme toggle event", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/status")

      # Send the toggle_theme event and make sure it doesn't crash
      result = view |> render_hook("toggle_theme")
      assert result =~ "System Status"
    end

    test "redirects anonymous users to login", %{} do
      # Create a non-authenticated connection
      anon_conn = build_conn()

      # Try to access the status page
      conn = get(anon_conn, ~p"/admin/status")

      # Should redirect to login page
      assert redirected_to(conn) =~ ~p"/session/new"
    end
    
    test "admin_header component works as expected", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/status")
      
      # Verify that the page title and subtitle are rendered correctly
      assert html =~ "System Status"
      assert html =~ "Monitor system health"
    end
  end
end