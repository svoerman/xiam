defmodule XIAMWeb.Plugs.AdminAuthPlugTest do
  use XIAMWeb.ConnCase, async: false
  
  alias XIAMWeb.Plugs.AdminAuthPlug
  alias Phoenix.Flash
  alias XIAM.Users.User
  alias Xiam.Rbac.Role
  alias Xiam.Rbac.Capability
  alias Phoenix.Controller
  
  # Create test data
  setup do
    admin_user = %User{
      id: 1,
      email: "admin@example.com",
      role: %Role{
        id: 1,
        name: "Admin",
        capabilities: [
          %Capability{
            id: 1,
            name: "admin_access",
            description: "Admin access"
          }
        ]
      }
    }
    
    regular_user = %User{
      id: 2,
      email: "user@example.com",
      role: %Role{
        id: 2,
        name: "User",
        capabilities: [
          %Capability{
            id: 2,
            name: "user_access",
            description: "User access"
          }
        ]
      }
    }
    
    %{admin_user: admin_user, regular_user: regular_user}
  end

  describe "AdminAuthPlug" do
    test "allows access when user has admin privileges", %{conn: conn, admin_user: admin_user} do
      # Set up connection with proper Pow configuration and flash
      conn = conn
        |> Plug.Test.init_test_session([])
        |> Pow.Plug.put_config(otp_app: :xiam)
        |> Controller.fetch_flash()
        |> Plug.Conn.assign(:current_user, admin_user)
      conn = AdminAuthPlug.call(conn, %{})
      
      refute conn.halted
      refute Flash.get(conn.assigns.flash, :error)
    end

    test "denies access when user does not have admin privileges", %{conn: conn, regular_user: regular_user} do
      conn = conn
        |> Plug.Test.init_test_session([])
        |> Pow.Plug.put_config(otp_app: :xiam)
        |> Controller.fetch_flash()
        |> Plug.Conn.assign(:current_user, regular_user)
      conn = AdminAuthPlug.call(conn, %{})
      
      assert conn.halted
      assert Flash.get(conn.assigns.flash, :error) == "You do not have permission to access this area."
      assert redirected_to(conn) == "/"
    end

    test "denies access when user is not logged in", %{conn: conn} do
      conn = conn
        |> Plug.Test.init_test_session([])
        |> Pow.Plug.put_config(otp_app: :xiam)
        |> Controller.fetch_flash()
      conn = AdminAuthPlug.call(conn, %{})
      
      assert conn.halted
      assert Flash.get(conn.assigns.flash, :error) == "You do not have permission to access this area."
      assert redirected_to(conn) == "/"
    end
    
    # Add a test that doesn't depend on mocking
    test "init returns options" do
      assert AdminAuthPlug.init(%{}) == %{}
    end
  end
end