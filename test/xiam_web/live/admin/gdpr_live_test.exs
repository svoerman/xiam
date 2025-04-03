defmodule XIAMWeb.Admin.GDPRLiveTest do
  use XIAMWeb.ConnCase

  import Phoenix.LiveViewTest
  alias XIAM.Users.User
  alias XIAM.Repo

  # Helper for test authentication
  def create_admin_user() do
    # Create a user
    {:ok, user} = %User{}
      |> User.pow_changeset(%{
        email: "gdpr_admin_user@example.com", 
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Repo.insert()

    # Create a role with admin capability
    {:ok, role} = %Xiam.Rbac.Role{
      name: "GDPR Admin Role",
      description: "Role with admin access"
    }
    |> Repo.insert()

    # Create a product for capabilities
    {:ok, product} = %Xiam.Rbac.Product{
      product_name: "GDPR Test Product",
      description: "Product for testing GDPR admin access"
    }
    |> Repo.insert()
    
    # Add admin capabilities
    {:ok, gdpr_capability} = %Xiam.Rbac.Capability{
      name: "admin_gdpr_access",
      description: "Admin GDPR access capability",
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
    |> Ecto.Changeset.put_assoc(:capabilities, [gdpr_capability, admin_capability])
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
    admin_user = create_admin_user()

    # Authenticate connection
    conn = login(conn, admin_user)

    # Return authenticated connection and users
    {:ok, conn: conn, admin_user: admin_user}
  end

  describe "GDPR LiveView" do
    test "mounts successfully", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/gdpr")

      # Verify page title is set correctly
      assert html =~ "GDPR Compliance Management"
      assert html =~ "Manage user consent, data portability, and the right to be forgotten"
    end

    test "displays user selection panel", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/gdpr")

      # Verify user selection panel exists
      assert has_element?(view, "h2", "Select User")
      assert has_element?(view, "label", "Select a user:")
      assert has_element?(view, "select#user_select")
    end

    test "handles theme toggle", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/gdpr")

      # Send the toggle_theme event
      result = view |> render_hook("toggle_theme")
      assert result =~ "GDPR Compliance Management"
    end

    test "redirects anonymous users to login", %{} do
      # Create a non-authenticated connection
      anon_conn = build_conn()

      # Try to access the GDPR page
      conn = get(anon_conn, ~p"/admin/gdpr")

      # Should redirect to login page
      assert redirected_to(conn) =~ ~p"/session/new"
    end
  end
end