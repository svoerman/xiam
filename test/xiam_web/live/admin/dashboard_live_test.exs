defmodule XIAMWeb.Admin.DashboardLiveTest do
  use XIAMWeb.ConnCase

  import Phoenix.LiveViewTest
  alias XIAM.Users.User
  alias XIAM.Repo

  # Helpers for test authentication
  def create_admin_user() do
    # Create a timestamp for unique email
    timestamp = System.system_time(:millisecond)

    # Create a user
    {:ok, user} = %User{}
      |> User.pow_changeset(%{
        email: "admin_dashboard_user_#{timestamp}@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Repo.insert()

    # Create a role with admin capability
    {:ok, role} = %Xiam.Rbac.Role{
      name: "Dashboard Admin Role #{timestamp}",
      description: "Role with admin access"
    }
    |> Repo.insert()

    # Create a product for capabilities
    {:ok, product} = %Xiam.Rbac.Product{
      product_name: "Dashboard Admin Test Product #{timestamp}",
      description: "Product for testing dashboard admin access"
    }
    |> Repo.insert()

    # Add admin capability
    {:ok, capability} = %Xiam.Rbac.Capability{
      name: "admin_access",
      description: "Admin dashboard access",
      product_id: product.id
    }
    |> Repo.insert()

    # Associate capability with role
    role
    |> Repo.preload(:capabilities)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:capabilities, [capability])
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

  describe "Dashboard LiveView" do
    test "mounts successfully", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin")

      # Verify page title is set correctly
      assert html =~ "XIAM Admin Dashboard"
      assert html =~ "Manage your CIAM system"
    end

    test "displays all admin dashboard cards", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin")

      # Check that all expected cards are displayed
      assert html =~ "User Management"
      assert html =~ "Roles &amp; Capabilities"
      assert html =~ "Entity Access"
      assert html =~ "Products &amp; Capabilities"
      assert html =~ "GDPR Compliance"
      assert html =~ "System Settings"
      assert html =~ "Audit Logs"
      assert html =~ "System Status"
      assert html =~ "Consent Records"
    end

    test "has working links to all sections", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin")

      # Test each link by making sure it exists and returns a valid response
      expected_links = [
        {"Manage Users", ~p"/admin/users"},
        {"Manage Roles", ~p"/admin/roles"},
        {"Manage Entity Access", ~p"/admin/entity-access"},
        {"Manage Products", ~p"/admin/products"},
        {"Manage GDPR", ~p"/admin/gdpr"},
        {"Manage Settings", ~p"/admin/settings"},
        {"View Logs", ~p"/admin/audit-logs"},
        {"View Status", ~p"/admin/status"},
        {"Manage Consents", ~p"/admin/consents"}
      ]

      for {link_text, path} <- expected_links do
        # Check that the link element exists
        assert has_element?(view, "a", link_text)

        # Check that the link has the correct destination
        assert has_element?(view, "a[href='#{path}']", link_text)
      end
    end

    test "handles theme toggle event", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin")

      # Send the toggle_theme event and make sure it doesn't crash
      result = view |> render_hook("toggle_theme")
      assert result =~ "XIAM Admin Dashboard"
    end

    test "assigns the correct page title", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin")

      # Test the internal socket assigns
      assert view.module == XIAMWeb.Admin.DashboardLive
      assert render(view) =~ "XIAM Admin Dashboard"

      # Get the socket assigns directly
      assert has_element?(view, "[data-test-id='page-title']", "Admin Dashboard")
    end

    test "admin_header component works as expected", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin")

      # Verify that the admin_header component renders correctly
      assert has_element?(view, ".admin-header")
      assert has_element?(view, "h1", "XIAM Admin Dashboard")
      assert has_element?(view, ".text-sm", "Manage your CIAM system")
    end

    test "all dashboard card components render correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin")

      # Verify all cards have the correct styling classes
      assert has_element?(view, ".grid .bg-card")
      assert has_element?(view, ".grid .rounded-lg")
      assert has_element?(view, ".grid .border")
      assert has_element?(view, ".grid .shadow-sm")

      # Count the number of cards
      cards = view |> element(".grid") |> render() |> Floki.parse_document!() |> Floki.find(".bg-card")
      assert length(cards) >= 9 # There should be at least 9 cards
    end

    test "redirects anonymous users to login", %{} do
      # Create a non-authenticated connection
      anon_conn = build_conn()

      # Try to access the dashboard
      conn = get(anon_conn, ~p"/admin")

      # Should redirect to login page
      assert redirected_to(conn) =~ ~p"/session/new"
    end
  end
end
