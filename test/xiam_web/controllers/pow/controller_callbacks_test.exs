defmodule XIAMWeb.Pow.ControllerCallbacksTest do
  use XIAMWeb.ConnCase
  
  alias XIAMWeb.Pow.ControllerCallbacks
  alias XIAM.Users.User
  alias Xiam.Rbac.{Role, Capability}
  alias XIAM.Repo
  
  describe "before_respond/4" do
    test "redirects admin users to admin panel after login" do
      # Get or create "Administrator" role
      role = case Repo.get_by(Role, name: "Administrator") do
        nil -> 
          {:ok, new_role} = %Role{name: "Administrator", description: "Admin role"}
          |> Repo.insert()
          new_role
        existing_role -> existing_role
      end
      
      # Create an admin capability and associate with role
      {:ok, capability} = %Capability{
        name: "admin_access",
        description: "Admin access capability",
        product_id: create_test_product().id
      }
      |> Repo.insert()
      
      # Associate capability with role
      role
      |> Repo.preload(:capabilities)
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:capabilities, [capability])
      |> Repo.update!()
      
      # Create admin user
      {:ok, user} = %User{}
      |> User.changeset(%{
        email: "admin-user#{System.unique_integer([:positive])}@example.com", 
        password: "Password123!", 
        password_confirmation: "Password123!"
      })
      |> Repo.insert()
      
      # Assign role to user
      {:ok, user} = user
      |> User.role_changeset(%{role_id: role.id})
      |> Repo.update()
      
      # Prepare connection with the user
      conn = build_conn()
      |> Plug.Test.init_test_session(%{})
      |> Pow.Plug.put_config(otp_app: :xiam)
      |> Pow.Plug.assign_current_user(user, otp_app: :xiam)
      |> Phoenix.ConnTest.fetch_flash()
      
      # Call before_respond for session creation
      {:ok, result_conn} = ControllerCallbacks.before_respond(
        Pow.Phoenix.SessionController,
        :create,
        {:ok, conn},
        []
      )
      
      # Verify admin redirect
      assert redirected_to(result_conn) == "/admin"
      assert Phoenix.Flash.get(result_conn.assigns.flash, :info) == "Welcome to the admin panel!"
    end
    
    test "doesn't redirect non-admin users" do
      # Create regular user
      {:ok, user} = %User{}
      |> User.changeset(%{
        email: "regular-user#{System.unique_integer([:positive])}@example.com", 
        password: "Password123!", 
        password_confirmation: "Password123!"
      })
      |> Repo.insert()
      
      # Prepare connection with the user
      conn = build_conn()
      |> Plug.Test.init_test_session(%{})
      |> Pow.Plug.put_config(otp_app: :xiam)
      |> Pow.Plug.assign_current_user(user, otp_app: :xiam)
      |> Phoenix.ConnTest.fetch_flash()
      
      # Call before_respond for session creation
      results = ControllerCallbacks.before_respond(
        Pow.Phoenix.SessionController,
        :create,
        {:ok, conn},
        []
      )
      
      # Verify no redirect for non-admin
      assert results == {:ok, conn}
    end
    
    test "passes through other controller actions" do
      conn = build_conn()
      results = ControllerCallbacks.before_respond(
        Pow.Phoenix.RegistrationController,
        :create,
        {:ok, conn},
        []
      )
      
      assert results == {:ok, conn}
    end
  end
  
  # Helper to create a test product
  defp create_test_product do
    {:ok, product} = %Xiam.Rbac.Product{
      product_name: "Test Product #{System.unique_integer([:positive])}",
      description: "Test product for auth"
    }
    |> Repo.insert()
    
    product
  end
end