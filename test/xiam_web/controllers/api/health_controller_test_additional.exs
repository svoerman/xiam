defmodule XIAMWeb.API.HealthControllerAdditionalTest do
  use XIAMWeb.ConnCase

  describe "health endpoint" do
    test "GET /api/health returns a JSON response with the proper structure", %{conn: conn} do
      conn = get(conn, ~p"/api/health")
      json_response = json_response(conn, 200)
      
      # Verify all required fields are present
      assert Map.has_key?(json_response, "status")
      assert Map.has_key?(json_response, "version")
      assert Map.has_key?(json_response, "timestamp")
    end
    
    test "health endpoint status is 'ok'", %{conn: conn} do
      conn = get(conn, ~p"/api/health")
      json_response = json_response(conn, 200)
      
      assert json_response["status"] == "ok"
    end
    
    test "health endpoint version follows semantic versioning", %{conn: conn} do
      conn = get(conn, ~p"/api/health")
      json_response = json_response(conn, 200)
      
      version = json_response["version"]
      assert is_binary(version)
      
      # Either 1.0.0 format or simple X.Y.Z format
      assert String.match?(version, ~r/^\d+\.\d+\.\d+$/)
    end
    
    test "health endpoint timestamp is a recent UTC datetime", %{conn: conn} do
      conn = get(conn, ~p"/api/health")
      json_response = json_response(conn, 200)
      
      timestamp_str = json_response["timestamp"]
      assert is_binary(timestamp_str)
      
      # Parse the timestamp
      {:ok, timestamp, _} = DateTime.from_iso8601(timestamp_str)
      
      # Check that the timestamp is recent (within the last minute)
      now = DateTime.utc_now()
      diff = DateTime.diff(now, timestamp, :second)
      assert diff < 60
    end
    
    test "health endpoint is accessible without authentication headers", %{conn: conn} do
      # Explicitly remove any auth headers to make sure endpoint is public
      conn = conn
             |> delete_req_header("authorization")
             |> get(~p"/api/health")
      
      assert json_response(conn, 200)["status"] == "ok"
    end
  end
end