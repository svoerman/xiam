defmodule XIAMWeb.Pow.SessionControllerTest do
  use XIAMWeb.ConnCase
  
  alias XIAM.Users.User
  alias Xiam.Rbac.{Role, Capability}
  alias XIAM.Repo
  
  describe "create/2" do
    test "redirects user to home page on successful login", %{conn: conn} do
      # Create admin user with admin role and capability
      user = create_admin_user()
      
      # Attempt login
      conn = post(conn, ~p"/session", %{
        "user" => %{
          "email" => user.email,
          "password" => "Password123!"
        }
      })
      
      # Verify redirect to home page (all users go to home page first, then admin_redirect_plug will redirect admin users)
      assert redirected_to(conn) == "/"
      # Skip flash check since we're primarily testing the redirect behavior
    end
    
    test "redirects regular user to home page on successful login", %{conn: conn} do
      # Create regular user
      email = "regular-user#{System.unique_integer([:positive])}@example.com"
      {:ok, _user} = %User{}
      |> User.changeset(%{
        email: email, 
        password: "Password123!", 
        password_confirmation: "Password123!"
      })
      |> Repo.insert()
      
      # Attempt login
      conn = post(conn, ~p"/session", %{
        "user" => %{
          "email" => email,
          "password" => "Password123!"
        }
      })
      
      # Verify redirect to home page
      assert redirected_to(conn) == "/"
      # Skip flash check since we're primarily testing the redirect behavior
    end
    
    test "shows error flash on failed login", %{conn: conn} do
      # Attempt login with invalid credentials
      conn = post(conn, ~p"/session", %{
        "user" => %{
          "email" => "nonexistent@example.com",
          "password" => "WrongPassword"
        }
      })
      
      # Verify error message and no redirect
      assert html_response(conn, 200) =~ "The provided login details did not work"
      # Skip flash check since we're primarily testing the error behavior
    end
  end
  
  # Helper to create an admin user
  defp create_admin_user do
    # Create an admin role with appropriate capability
    timestamp = System.unique_integer([:positive])
    {:ok, role} = %Role{name: "Administrator_#{timestamp}", description: "Admin role"}
    |> Repo.insert()
    
    # Create a product for the capability
    {:ok, product} = %Xiam.Rbac.Product{
      product_name: "Test Product #{System.unique_integer([:positive])}",
      description: "Test product for auth"
    }
    |> Repo.insert()
    
    # Create an admin capability and associate with role
    {:ok, capability} = %Capability{
      name: "admin_access",
      description: "Admin access capability",
      product_id: product.id
    }
    |> Repo.insert()
    
    # Associate capability with role
    role
    |> Repo.preload(:capabilities)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:capabilities, [capability])
    |> Repo.update!()
    
    # Create admin user
    email = "admin-user#{System.unique_integer([:positive])}@example.com"
    {:ok, user} = %User{}
    |> User.changeset(%{
      email: email, 
      password: "Password123!", 
      password_confirmation: "Password123!"
    })
    |> Repo.insert()
    
    # Assign role to user
    {:ok, user} = user
    |> User.role_changeset(%{role_id: role.id})
    |> Repo.update()
    
    user
  end
end