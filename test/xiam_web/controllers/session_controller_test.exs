defmodule XIAMWeb.SessionControllerTest do
  use XIAMWeb.ConnCase, async: false
  import Mock

  # Define a mock User struct
  defmodule MockUser do
    defstruct [:id, :email, :role]
  end

  # Define a mock Role struct
  defmodule MockRole do
    defstruct [:id, :name, :capabilities]
  end

  # Define a mock Capability struct
  defmodule MockCapability do
    defstruct [:id, :name]
  end

  test_with_mock "returns home path for regular users", %{conn: conn}, XIAM.Repo, [], 
    [preload: fn(user, _) -> user end] do
    
    # Create a user struct with no role
    user = %MockUser{id: 1, email: "regular@example.com", role: nil}
      
    # Test the function
    path = XIAMWeb.SessionController.after_sign_in_path(conn, user)
    assert path == "/"
  end

  test_with_mock "returns admin path for admin users", %{conn: conn}, XIAM.Repo, [],
    [preload: fn(user, _) -> user end] do
    
    # Create an admin user struct
    user = %MockUser{
      id: 2, 
      email: "admin@example.com",
      role: %MockRole{
        id: 1,
        name: "Administrator",
        capabilities: [
          %MockCapability{id: 1, name: "admin_access"}
        ]
      }
    }
      
    # Test the function
    path = XIAMWeb.SessionController.after_sign_in_path(conn, user)
    assert path == "/admin"
  end

  test_with_mock "returns home path for non-admin roles", %{conn: conn}, XIAM.Repo, [],
    [preload: fn(user, _) -> user end] do
    
    # Create a user with non-admin role
    user = %MockUser{
      id: 3,
      email: "editor@example.com",
      role: %MockRole{
        id: 2,
        name: "Editor",
        capabilities: []
      }
    }
      
    # Test the function
    path = XIAMWeb.SessionController.after_sign_in_path(conn, user)
    assert path == "/"
  end
end
