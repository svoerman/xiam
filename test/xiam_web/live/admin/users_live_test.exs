require XIAMWeb.Router

defmodule XIAMWeb.Admin.UsersLiveTest do
  use XIAMWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  alias XIAM.Repo
  alias XIAM.Users.User
  alias Xiam.Rbac.Role

  defp create_admin_user_for_test(attrs) do
    default_attrs = %{
      email: "admin_#{"#{System.system_time(:millisecond)}_#{:rand.uniform(100_000)}"}@example.com",
      name: "Admin User",
      admin: true,
      password: "password123",
      password_confirmation: "password123"
    }
    merged_attrs = Enum.into(attrs, default_attrs)

    %User{}
    |> User.changeset(merged_attrs)
    |> Repo.insert!()
  end

  setup :setup_test_environment

  defp setup_test_environment(%{conn: conn}) do
    administrator_role =
      Repo.get_by(Role, name: "Administrator") ||
        Repo.insert!(%Role{name: "Administrator", description: "Administrator role"})
    admin = create_admin_user_for_test(%{role_id: administrator_role.id, admin: true})
    admin = Repo.get!(User, admin.id) # reload to ensure role_id is present
    admin_conn = log_in_user(conn, admin)
    admin_conn = Phoenix.ConnTest.init_test_session(admin_conn, %{"pow_user_id" => admin.id})


    test_user_attrs = %{
      email: "test_#{"#{System.system_time(:millisecond)}_#{:rand.uniform(100_000)}"}@example.com",
      name: "Regular Test User",
      password: "password123",
      password_confirmation: "password123"
    }
    test_user =
      %User{}
      |> User.changeset(test_user_attrs)
      |> Repo.insert!()

    standard_role = %Role{name: "Standard_#{"#{System.system_time(:millisecond)}_#{:rand.uniform(100_000)}"}", description: "Standard user role"}
    |> Repo.insert!()

    role_user = %User{}
      |> User.changeset(%{
        email: "role_user_#{"#{System.system_time(:millisecond)}_#{:rand.uniform(100_000)}"}@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Repo.insert!()

    {:ok, role_user} = role_user
      |> User.role_changeset(%{role_id: standard_role.id})
      |> Repo.update()

    mfa_user = %User{}
      |> User.changeset(%{
        email: "mfa_user_#{"#{System.system_time(:millisecond)}_#{:rand.uniform(100_000)}"}@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Repo.insert!()

    secret = User.generate_totp_secret()
    backup_codes = User.generate_backup_codes()

    {:ok, mfa_user} = mfa_user
      |> User.mfa_changeset(%{
        mfa_enabled: true,
        mfa_secret: secret,
        mfa_backup_codes: backup_codes
      })
      |> Repo.update()

    {:ok,
     conn: admin_conn,
     admin: admin,
     test_user: test_user,
     regular_user: test_user,
     standard_role: standard_role,
     role_user: role_user,
     mfa_user: mfa_user}
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

    test "can open edit modal for a user", %{conn: conn, admin: _admin, regular_user: regular_user} do
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      # Open edit modal for regular user directly with the event
      rendered = view
      |> render_hook("show_edit_modal", %{"id" => regular_user.id})

      # Verify modal is displayed with user info
      assert rendered =~ "Edit User"
      assert rendered =~ regular_user.email
      assert rendered =~ "Assign Role"
    end

    test "can update user role", %{conn: conn, admin: _admin, regular_user: regular_user, standard_role: standard_role} do
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

    test "can remove user role", %{conn: conn, admin: _admin, role_user: role_user} do
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

    test "can toggle MFA for a user", %{conn: conn, admin: _admin, regular_user: regular_user, mfa_user: mfa_user} do
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

    test "displays not found message for invalid user ID", %{conn: conn, admin: _admin} do
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

    test "can open MFA setup modal", %{conn: conn, admin: _admin, regular_user: regular_user} do
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      # Click the Enable MFA button
      rendered = view
      |> render_click("toggle_mfa", %{"id" => regular_user.id})

      # Verify MFA setup modal content
      assert rendered =~ "Enable Multi-Factor Authentication"
      assert rendered =~ "Scan this QR code with your authenticator app"
      assert rendered =~ "Or enter this code manually"
      assert rendered =~ "Save these backup codes"
      assert rendered =~ regular_user.email
    end

    test "can enable MFA for user", %{conn: conn, admin: _admin, regular_user: regular_user} do
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      # Open MFA setup modal
      view
      |> render_click("toggle_mfa", %{"id" => regular_user.id})

      # Click Enable MFA button
      rendered = view
      |> render_click("enable_mfa")

      # Verify success message
      assert rendered =~ "MFA enabled successfully"

      # Verify database update
      updated_user = Repo.get(User, regular_user.id)
      assert updated_user.mfa_enabled == true
      assert updated_user.mfa_secret != nil
      assert updated_user.mfa_backup_codes != nil
    end

    test "can disable MFA for user", %{conn: conn, admin: _admin, mfa_user: mfa_user} do
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      # Click Disable MFA button
      rendered = view
      |> render_click("toggle_mfa", %{"id" => mfa_user.id})

      # Verify success message
      assert rendered =~ "MFA disabled for user"

      # Verify database update
      updated_user = Repo.get(User, mfa_user.id)
      assert updated_user.mfa_enabled == false
      assert updated_user.mfa_secret == nil
      assert updated_user.mfa_backup_codes == nil
    end

    test "MFA setup modal shows QR code and backup codes", %{conn: conn, admin: _admin, regular_user: regular_user} do
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      # Open MFA setup modal
      rendered = view
      |> render_click("toggle_mfa", %{"id" => regular_user.id})

      # Verify QR code and backup codes are present
      assert rendered =~ "<svg" # QR code SVG
      assert rendered =~ "otpauth://totp/XIAM:" # TOTP URI
      assert rendered =~ ~r/[a-z0-9]{8}/ # Backup codes format
    end
  end
end
