defmodule XIAMWeb.API.HealthControllerTest do
  use XIAMWeb.ConnCase

  import Mock

  describe "health endpoints" do
    test "GET /api/health returns basic health status", %{conn: conn} do
      conn = get(conn, ~p"/api/health")
      
      # Verify the response structure
      assert json_response(conn, 200)["status"] == "ok"
      assert json_response(conn, 200)["version"]
      assert json_response(conn, 200)["timestamp"]
      
      # Verify timestamp format (ISO8601)
      timestamp = json_response(conn, 200)["timestamp"]
      assert String.match?(timestamp, ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end
    
    test "GET /api/health/detailed returns detailed health data", %{conn: conn} do
      conn = get(conn, ~p"/api/health/detailed")
      
      # Verify response structure
      response = json_response(conn, 200)
      assert response["status"] == "ok"
      assert response["version"]
      assert response["timestamp"]
      assert response["environment"]
      
      # Verify system info
      assert response["system"]["architecture"]
      assert response["system"]["uptime_days"]
      assert response["system"]["process_count"]
      
      # Verify memory info
      assert response["system"]["memory"]["total"]
      assert response["system"]["memory"]["processes"]
      assert response["system"]["memory"]["atom"]
      assert response["system"]["memory"]["binary"]
      
      # Verify database status
      assert response["database"]["status"] == "connected"
    end
    
    test "health endpoint handles database errors", %{conn: conn} do
      # Mock the database query to simulate a failure
      with_mock XIAM.Repo, [query: fn _query -> :error end] do
        conn = get(conn, ~p"/api/health/detailed")
        
        # Verify the response still has the basic structure
        response = json_response(conn, 200)
        assert response["status"] == "ok"
        
        # But database status should be error
        assert response["database"]["status"] == "error"
      end
    end
  end
end