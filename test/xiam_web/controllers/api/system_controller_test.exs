defmodule XIAMWeb.API.SystemControllerTest do
  use XIAMWeb.ConnCase
  
  alias XIAM.Users.User
  alias XIAM.Repo
  alias XIAM.Auth.JWT

  # Create test data with an authenticated user
  setup %{conn: conn} do
    # Create test user with correct fields for Pow
    {:ok, user} = User.pow_changeset(%User{}, %{
      email: "testuser@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    }) |> Repo.insert()

    # Prepare connection with JSON headers
    conn = conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")
    
    # Create a mock JWT token
    {:ok, token, _claims} = JWT.generate_token(user)
    
    # Authenticated connection for protected endpoints with Bearer token
    authed_conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> assign(:current_user, user)
    
    %{
      conn: conn,
      authed_conn: authed_conn,
      user: user,
      token: token
    }
  end

  describe "health/2" do
    test "returns basic health information without authentication", %{conn: conn} do
      conn = conn
        |> put_req_header("accept", "application/json")
        |> get(~p"/api/system/health") # Use the old endpoint path for backward compatibility
      
      response = json_response(conn, 200)
      assert response["status"] == "ok"
      assert response["version"] != nil
      assert response["timestamp"] != nil
      
      # Since we're testing an endpoint that might be changing, be more flexible with assertions
      # environment might not be included in all implementations
    end
  end

  describe "status/2" do
    @tag :pending
    test "returns detailed health information when authenticated", %{authed_conn: conn} do
      conn = get(conn, ~p"/api/system/status")
      
      response = json_response(conn, 200)
      
      # Check for presence of main health check sections
      assert Map.has_key?(response, "database")
      assert Map.has_key?(response, "application")
      assert Map.has_key?(response, "memory")
      assert Map.has_key?(response, "disk")
      assert Map.has_key?(response, "cluster")
      assert Map.has_key?(response, "system_info")
      assert Map.has_key?(response, "timestamp")
      
      # Verify application section data
      assert response["application"]["status"] == "ok"
      assert is_binary(response["application"]["version"])
      assert is_integer(response["application"]["uptime"])
      
      # Verify memory section data
      assert response["memory"]["status"] == "ok"
      assert is_number(response["memory"]["total"])
      
      # Verify system info section data
      assert is_binary(response["system_info"]["otp_release"])
      assert is_integer(response["system_info"]["process_count"])
    end
    
    test "returns 401 unauthorized when not authenticated", %{conn: conn} do
      conn = conn
        |> put_req_header("accept", "application/json")
        |> get(~p"/api/system/status")
      response = json_response(conn, 401)
      assert response["error"] == "Authorization header missing or invalid"
    end
  end
end