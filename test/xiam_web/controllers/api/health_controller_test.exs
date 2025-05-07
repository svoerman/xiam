defmodule XIAMWeb.API.HealthControllerTest do
  use XIAMWeb.ConnCase, async: false

  import Mock
  import XIAM.ETSTestHelper

  describe "health endpoints" do
    test "GET /api/health returns basic health status", %{conn: conn} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Use safely_execute_ets_operation for API requests
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        conn = get(conn, ~p"/api/health")
        
        # Verify response behavior rather than implementation
        response = json_response(conn, 200)
        
        # Basic health check should always return these fields
        assert response["status"] == "ok", "Expected health status to be 'ok'"
        assert response["version"], "Expected version to be present"
        assert response["timestamp"], "Expected timestamp to be present"
        
        # Verify timestamp format (ISO8601)
        timestamp = response["timestamp"]
        assert String.match?(timestamp, ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/), "Expected ISO8601 timestamp format"
      end)
    end
    
    test "GET /api/health/detailed returns detailed health data", %{conn: conn} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Use safely_execute_ets_operation for API requests
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        conn = get(conn, ~p"/api/health/detailed")
        
        # Verify response behavior - focus on structure and content
        response = json_response(conn, 200)
        assert response["status"] == "ok", "Expected health status to be 'ok'"
        assert response["version"], "Expected version to be present"
        assert response["timestamp"], "Expected timestamp to be present"
        assert response["environment"], "Expected environment to be present"
        
        # Verify system info - testing behavior not implementation
        assert response["system"]["architecture"], "Expected architecture info to be present"
        assert response["system"]["uptime_days"], "Expected uptime info to be present"
        assert response["system"]["process_count"], "Expected process count to be present"
        
        # Verify memory info - focusing on response structure
        assert response["system"]["memory"]["total"], "Expected total memory info"
        assert response["system"]["memory"]["processes"], "Expected processes memory info"
        assert response["system"]["memory"]["atom"], "Expected atom memory info"
        assert response["system"]["memory"]["binary"], "Expected binary memory info"
        
        # Verify database status - key functional behavior
        assert response["database"]["status"] == "connected", "Expected database to be connected"
      end)
    end
    
    test "health endpoint handles database errors", %{conn: conn} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Use safely_execute_ets_operation with mocking for API requests
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        # Mock the database query to simulate a failure
        with_mock XIAM.Repo, [query: fn _query -> :error end] do
          conn = get(conn, ~p"/api/health/detailed")
          
          # Verify the response behavior when database fails
          response = json_response(conn, 200)
          
          # Overall status should still be ok since the service is running
          assert response["status"] == "ok", "Expected overall status to remain 'ok' despite DB errors"
          
          # But database component status should reflect the error
          assert response["database"]["status"] == "error", "Expected database status to be 'error'"
        end
      end)
    end
    
    test "GET /api/system/health returns backward compatible health response", %{conn: conn} do
      # Ensure ETS tables exist before making API requests
      ensure_ets_tables_exist()
      
      # Use safely_execute_ets_operation for API requests
      XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
        # Test the backward compatible endpoint
        conn = get(conn, ~p"/api/system/health")
        
        # Verify response follows expected structure
        response = json_response(conn, 200)
        assert response["status"] == "ok", "Expected health status to be 'ok'"
        assert response["version"], "Expected version to be present"
        assert response["timestamp"], "Expected timestamp to be present"
      end)
    end
  end
end