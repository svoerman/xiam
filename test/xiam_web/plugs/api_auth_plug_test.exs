defmodule XIAMWeb.Plugs.APIAuthPlugTest do
  use XIAMWeb.ConnCase

  alias XIAMWeb.Plugs.APIAuthPlug
  alias XIAM.Users.User
  alias XIAM.Auth.JWT
  alias XIAM.Repo

  setup %{conn: conn} do
    # Explicitly ensure repo is available
    case Process.whereis(XIAM.Repo) do
      nil ->
        # Repo is not started, try to start it explicitly
        {:ok, _} = Application.ensure_all_started(:ecto_sql)
        {:ok, _} = XIAM.Repo.start_link([])
        # Set sandbox mode
        Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
      _ -> 
        :ok
    end
    
    # Generate a unique email for this test run
    timestamp = System.system_time(:second)
    test_email = "api_plug_test_#{timestamp}@example.com"
    
    # Delete any existing test users that might cause conflicts
    import Ecto.Query
    Repo.delete_all(from u in User, where: like(u.email, "%api_plug_test%"))
    
    # Create a test user with the unique email
    {:ok, user} = %User{}
      |> User.pow_changeset(%{
        email: test_email,
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Repo.insert()

    # Generate a valid token
    {:ok, token, _claims} = JWT.generate_token(user)

    conn = conn
      |> put_req_header("accept", "application/json")

    {:ok, conn: conn, user: user, token: token}
  end

  describe "APIAuthPlug" do
    test "allows requests with valid tokens", %{conn: conn, user: user, token: token} do
      # Add the token to the request
      conn = conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> APIAuthPlug.call([])

      # Verify the plug assigns the user and claims
      assert conn.assigns.current_user.id == user.id
      assert to_string(conn.assigns.jwt_claims["sub"]) == to_string(user.id)
      assert not conn.halted
    end

    test "rejects requests with missing token", %{conn: conn} do
      # Call the plug without a token
      conn = APIAuthPlug.call(conn, [])

      # Verify the plug halts the connection
      assert conn.halted
      assert conn.status == 401
      assert Jason.decode!(conn.resp_body)["error"] =~ "missing or invalid"
    end

    test "rejects requests with invalid token format", %{conn: conn} do
      # Add an invalid token format
      conn = conn
        |> put_req_header("authorization", "InvalidFormat token123")
        |> APIAuthPlug.call([])

      # Verify the plug halts the connection
      assert conn.halted
      assert conn.status == 401
      assert Jason.decode!(conn.resp_body)["error"] =~ "Invalid token format"
    end

    test "rejects requests with expired or tampered token", %{conn: conn, token: token} do
      # Tamper with the token
      tampered_token = token <> "a"
      
      conn = conn
        |> put_req_header("authorization", "Bearer #{tampered_token}")
        |> APIAuthPlug.call([])

      # Verify the plug halts the connection
      assert conn.halted
      assert conn.status == 401
      assert Jason.decode!(conn.resp_body)["error"] =~ "Invalid token"
    end

    test "has_capability?/2 delegates to AuthHelpers", %{user: user} do
      # Preload role and capabilities
      user = user |> Repo.preload(role: :capabilities)
      
      # Test the delegation - should match AuthHelpers behavior
      result = APIAuthPlug.has_capability?(user, "test_capability")
      assert is_boolean(result)
    end
  end
end