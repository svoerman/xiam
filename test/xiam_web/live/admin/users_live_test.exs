defmodule XIAMWeb.Admin.UsersLiveTest do
  use XIAMWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias XIAM.Users.User
  alias Xiam.Rbac.{Role, Capability}
  alias XIAM.Repo

  # Helper for test authentication
  def create_admin_user() do
    # Create a user
    email = "admin_user_#{System.unique_integer([:positive])}@example.com"
    {:ok, user} = %User{}
      |> User.changeset(%{
        email: email,
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Repo.insert()

    # Create a role with admin capability
    timestamp = System.unique_integer([:positive])
    {:ok, role} = %Role{name: "Administrator_#{timestamp}", description: "Admin role"}
    |> Repo.insert()

    # Create a product for capabilities
    {:ok, product} = %Xiam.Rbac.Product{
      product_name: "Admin Test Product",
      description: "Product for testing admin access"
    }
    |> Repo.insert()
    
    # Add admin capability
    {:ok, capability} = %Capability{
      name: "admin_access",
      description: "Admin access",
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
    # Create admin user for authentication
    admin = create_admin_user()
    
    # Create test users with different roles
    {:ok, regular_user} = %User{}
      |> User.changeset(%{
        email: "user_#{System.unique_integer([:positive])}@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Repo.insert()
      
    # Create a standard role (not admin)
    timestamp = System.unique_integer([:positive])
    {:ok, standard_role} = %Role{name: "Standard_#{timestamp}", description: "Standard user role"}
    |> Repo.insert()
    
    # Create another user with a role
    {:ok, role_user} = %User{}
      |> User.changeset(%{
        email: "role_user_#{System.unique_integer([:positive])}@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Repo.insert()
      
    # Assign role
    {:ok, role_user} = role_user
      |> User.role_changeset(%{role_id: standard_role.id})
      |> Repo.update()
      
    # Create MFA-enabled user
    {:ok, mfa_user} = %User{}
      |> User.changeset(%{
        email: "mfa_user_#{System.unique_integer([:positive])}@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Repo.insert()
      
    # Enable MFA
    secret = User.generate_totp_secret()
    backup_codes = User.generate_backup_codes()
    
    {:ok, mfa_user} = mfa_user
      |> User.mfa_changeset(%{
        mfa_enabled: true,
        mfa_secret: secret,
        mfa_backup_codes: backup_codes
      })
      |> Repo.update()
    
    # Authenticate connection as admin
    conn = login(conn, admin)
    
    {:ok, 
      conn: conn, 
      admin: admin, 
      regular_user: regular_user, 
      role_user: role_user, 
      mfa_user: mfa_user, 
      standard_role: standard_role
    }
  end
  
  describe "Users LiveView" do
    test "displays users table with all users", %{conn: conn, regular_user: regular_user, role_user: role_user, mfa_user: mfa_user} do
      {:ok, _view, html} = live(conn, ~p"/admin/users")
      
      # Verify page title and content
      assert html =~ "User Management"
      assert html =~ "Manage user accounts"
      
      # Check that all test users are displayed
      assert html =~ regular_user.email
      assert html =~ role_user.email
      assert html =~ mfa_user.email
      
      # Check role and MFA status indicators
      assert html =~ "No Role" # For regular_user
      assert html =~ "Standard" # For role_user
      assert html =~ "Enabled" # For mfa_user's MFA status
      assert html =~ "Disabled" # For other users' MFA status
    end
    
    test "can open edit modal for a user", %{conn: conn, regular_user: regular_user} do
      {:ok, view, _html} = live(conn, ~p"/admin/users")
      
      # Open edit modal for regular user directly with the event
      rendered = view
      |> render_hook("show_edit_modal", %{"id" => regular_user.id})
      
      # Verify modal is displayed with user info
      assert rendered =~ "Edit User"
      assert rendered =~ regular_user.email
      assert rendered =~ "Assign Role"
    end
    
    test "can update user role", %{conn: conn, regular_user: regular_user, standard_role: standard_role} do
      {:ok, view, _html} = live(conn, ~p"/admin/users")
      
      # Open edit modal for regular user directly with the event
      view
      |> render_hook("show_edit_modal", %{"id" => regular_user.id})
      
      # Submit form to update role
      rendered = view
      |> form("form", %{"user" => %{"role_id" => standard_role.id}})
      |> render_submit()
      
      # Verify success message by checking the rendered content
      assert rendered =~ "User role updated successfully"
      
      # Verify database update
      updated_user = Repo.get(User, regular_user.id) |> Repo.preload(:role)
      assert updated_user.role_id == standard_role.id
      assert updated_user.role.name == standard_role.name
    end
    
    test "can remove user role", %{conn: conn, role_user: role_user} do
      {:ok, view, _html} = live(conn, ~p"/admin/users")
      
      # Open edit modal for role user directly with the event
      view
      |> render_hook("show_edit_modal", %{"id" => role_user.id})
      
      # Submit form to remove role (empty role_id)
      rendered = view
      |> form("form", %{"user" => %{"role_id" => ""}})
      |> render_submit()
      
      # Verify success message by checking the rendered content
      assert rendered =~ "User role updated successfully"
      
      # Verify database update
      updated_user = Repo.get(User, role_user.id) |> Repo.preload(:role)
      assert updated_user.role_id == nil
      assert updated_user.role == nil
    end
    
    test "can toggle MFA for a user", %{conn: conn, regular_user: regular_user, mfa_user: mfa_user} do
      {:ok, view, _html} = live(conn, ~p"/admin/users")
      
      # Disable MFA for mfa_user using the event directly
      view
      |> render_hook("toggle_mfa", %{"id" => mfa_user.id})
      
      # Verify success message
      assert render(view) =~ "MFA disabled for user"
      
      # Verify database update
      updated_mfa_user = Repo.get(User, mfa_user.id)
      refute updated_mfa_user.mfa_enabled
      assert updated_mfa_user.mfa_secret == nil
      
      # Enable MFA for regular_user using the event directly
      rendered = view
      |> render_hook("toggle_mfa", %{"id" => regular_user.id})
      
      # Verify MFA setup modal is shown
      assert rendered =~ "Enable Multi-Factor Authentication"
      assert rendered =~ "Scan this QR code"
      assert rendered =~ "Save these backup codes"
      
      # Complete MFA setup using the event directly
      view
      |> render_hook("enable_mfa", %{})
      
      # Verify success message
      assert render(view) =~ "MFA enabled successfully"
      
      # Verify database update
      updated_regular_user = Repo.get(User, regular_user.id)
      assert updated_regular_user.mfa_enabled
      assert updated_regular_user.mfa_secret != nil
      assert updated_regular_user.mfa_backup_codes != nil
    end
    
    test "displays not found message for invalid user ID", %{conn: conn} do
      # Try to access a user that doesn't exist
      # The route will redirect immediately, so we need to handle that
      {:error, {:live_redirect, %{to: redirect_path, flash: flash}}} = live(conn, ~p"/admin/users/999999")
      
      # Verify error message and redirect
      assert redirect_path == "/admin/users"
      assert flash["error"] == "User not found"
    end
    
    test "can handle errors when updating user", %{conn: conn, admin: _admin} do
      {:ok, view, _html} = live(conn, ~p"/admin/users")
      
      # Send the update_user_role event directly without a user selected
      rendered = view
      |> render_hook("update_user_role", %{"user" => %{"role_id" => ""}})
      
      # Verify error message
      assert rendered =~ "No user selected"
    end
  end
end