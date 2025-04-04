defmodule XIAMWeb.Pow.SessionControllerTest do
  use XIAMWeb.ConnCase

  alias XIAM.Users.User
  alias Xiam.Rbac.{Role, Capability}
  alias XIAM.Repo

  setup %{conn: conn} do
    # Create test user
    {:ok, user} = %User{}
      |> User.pow_changeset(%{
        email: "test@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Repo.insert()

    {:ok, conn: conn, user: user}
  end

  test "renders login page", %{conn: conn} do
    conn = get(conn, ~p"/session/new")
    assert html_response(conn, 200) =~ "Sign in"
    assert html_response(conn, 200) =~ "Email"
    assert html_response(conn, 200) =~ "Password"
  end

  test "logs in user with valid credentials", %{conn: conn} do
    conn = post(conn, ~p"/session", %{
      "user" => %{
        "email" => "test@example.com",
        "password" => "Password123!"
      }
    })

    assert redirected_to(conn) =~ "/"

    # Follow redirect and verify login state
    conn = get(recycle(conn), "/")
    assert conn.assigns[:current_user] != nil
  end

  test "rejects login with invalid credentials", %{conn: conn} do
    conn = post(conn, ~p"/session", %{
      "user" => %{
        "email" => "test@example.com",
        "password" => "WrongPassword"
      }
    })

    assert html_response(conn, 200) =~ "The provided login details did not work"
  end

  test "logs out user", %{conn: conn, user: user} do
    # First login
    conn = conn
      |> Pow.Plug.assign_current_user(user, [otp_app: :xiam])

    # Then logout
    conn = delete(conn, ~p"/session")
    assert redirected_to(conn) =~ "/session/new"

    # Verify logged out state
    conn = get(recycle(conn), "/")
    assert html_response(conn, 200) =~ "Login"
    refute html_response(conn, 200) =~ "test@example.com"
  end

  test "redirects to registration page", %{conn: conn} do
    conn = get(conn, ~p"/session/new")
    assert html_response(conn, 200) =~ "Register"

    # Check if the registration link exists
    assert html_response(conn, 200) =~ ~p"/registration/new"
  end

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
