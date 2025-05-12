defmodule XIAMWeb.Plugs.AdminRedirectPlugTest do
  use XIAMWeb.ConnCase, async: false

  alias XIAMWeb.Plugs.AdminRedirectPlug
  alias XIAM.Users.User
  alias Xiam.Rbac.{Role, Capability}
  alias XIAM.Repo
  
  # Ensure the Ecto Repo is properly started and configured for these tests
  setup_all do
    # Start the Ecto repository explicitly before running tests
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    
    # Ensure the repo is started and in sandbox mode
    try do
      Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo)
      Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
    rescue
      e -> 
        IO.puts("Error setting up Repo: #{inspect(e)}")
        :ok
    end
    
    :ok
  end

  describe "call/2" do
    setup %{conn: _conn} do
      # Create admin role with capability (with timestamp to avoid name collision)
      timestamp = System.unique_integer([:positive])
      _role_name = "Administrator_#{timestamp}"
      
      # First check if a role with this name already exists - for test isolation
      existing_role = Repo.get_by(Role, name: "Administrator")
      
      role = 
        if existing_role do
          # Use the existing Administrator role if it exists
          existing_role
        else
          # Otherwise create a new role
          {:ok, new_role} = %Role{
            name: "Administrator",
            description: "Admin Role #{timestamp}"
          }
          |> Repo.insert()
          
          new_role
        end

      # Create a product for the capability
      {:ok, product} = %Xiam.Rbac.Product{
        product_name: "Test Product #{timestamp}",
        description: "Test product"
      }
      |> Repo.insert()

      # Create admin capability
      {:ok, capability} = %Capability{
        name: "admin_access",
        description: "Admin access capability",
        product_id: product.id
      }
      |> Repo.insert()

      # Associate capability with role
      role = role
      |> Repo.preload(:capabilities)
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:capabilities, [capability])
      |> Repo.update!()

      # Create a standard role without admin capability
      {:ok, standard_role} = %Role{
        name: "StandardUser_#{timestamp}",
        description: "Standard Role"
      }
      |> Repo.insert()

      # Create admin user
      {:ok, admin_user} = %User{}
      |> User.changeset(%{
        email: "admin_#{timestamp}@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Repo.insert()

      # Assign admin role
      {:ok, admin_user} = admin_user
      |> User.role_changeset(%{role_id: role.id})
      |> Repo.update()

      # Create regular user
      {:ok, regular_user} = %User{}
      |> User.changeset(%{
        email: "user_#{timestamp}@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Repo.insert()

      # Assign standard role
      {:ok, regular_with_role} = regular_user
      |> User.role_changeset(%{role_id: standard_role.id})
      |> Repo.update()

      # Create another user with no role
      {:ok, no_role_user} = %User{}
      |> User.changeset(%{
        email: "norole_#{timestamp}@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Repo.insert()

      {:ok, %{
        admin_user: admin_user,
        regular_user: regular_user,
        role_user: regular_with_role,
        no_role_user: no_role_user
      }}
    end

    test "redirects admin users to admin dashboard when accessing homepage", %{conn: conn, admin_user: admin_user} do
      # Create a connection with a logged in admin user
      conn = conn
      |> Plug.Test.init_test_session(%{})
      |> Pow.Plug.put_config(otp_app: :xiam)
      |> Pow.Plug.assign_current_user(admin_user, [])
      |> Map.put(:request_path, "/")

      # Fetch flash first
      conn = conn
      |> Phoenix.ConnTest.fetch_flash()
      
      # Run the plug
      conn = AdminRedirectPlug.call(conn, [])

      # Verify redirection
      assert redirected_to(conn) == "/admin"
      assert conn.halted
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Welcome to the admin dashboard!"
    end

    test "doesn't redirect admin users for non-homepage paths", %{conn: conn, admin_user: admin_user} do
      # Create a connection with a logged in admin user but for a different path
      conn = conn
      |> Plug.Test.init_test_session(%{})
      |> Pow.Plug.put_config(otp_app: :xiam)
      |> Pow.Plug.assign_current_user(admin_user, [])
      |> Map.put(:request_path, "/some-other-page")

      # Run the plug
      result_conn = AdminRedirectPlug.call(conn, [])

      # Verify no redirection - connection should be unchanged
      assert result_conn == conn
      refute result_conn.halted
    end

    test "doesn't redirect regular users with role", %{conn: conn, role_user: regular_user} do
      # Create a connection with a logged in regular user
      conn = conn
      |> Plug.Test.init_test_session(%{})
      |> Pow.Plug.put_config(otp_app: :xiam)
      |> Pow.Plug.assign_current_user(regular_user, [])
      |> Map.put(:request_path, "/")

      # Run the plug
      result_conn = AdminRedirectPlug.call(conn, [])

      # Verify no redirection
      assert result_conn == conn
      refute result_conn.halted
    end

    test "doesn't redirect users without role", %{conn: conn, no_role_user: no_role_user} do
      # Create a connection with a logged in user without role
      conn = conn
      |> Plug.Test.init_test_session(%{})
      |> Pow.Plug.put_config(otp_app: :xiam)
      |> Pow.Plug.assign_current_user(no_role_user, [])
      |> Map.put(:request_path, "/")

      # Run the plug
      result_conn = AdminRedirectPlug.call(conn, [])

      # Verify no redirection
      assert result_conn == conn
      refute result_conn.halted
    end

    test "doesn't redirect when no user is logged in", %{conn: conn} do
      # Create a connection with no user logged in
      conn = conn
      |> Plug.Test.init_test_session(%{})
      |> Pow.Plug.put_config(otp_app: :xiam)
      |> Map.put(:request_path, "/")

      # Run the plug
      result_conn = AdminRedirectPlug.call(conn, [])

      # Verify no redirection
      assert result_conn == conn
      refute result_conn.halted
    end

    test "init/1 returns options unchanged" do
      opts = [some: "option"]
      assert AdminRedirectPlug.init(opts) == opts
    end
  end
end