defmodule XIAMWeb.SwaggerControllerTest do
  use XIAMWeb.ConnCase, async: false
  import Mock
  import Phoenix.ConnTest
  import XIAM.ETSTestHelper

  test "renders swagger UI page", %{conn: conn} do
    # Ensure ETS tables exist before making API requests
    ensure_ets_tables_exist()
    
    # Use safely_execute_ets_operation for API requests
    XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
      conn = get(conn, ~p"/api/docs")
      html = html_response(conn, 200)

      # Verify the page contains swagger UI - focus on behavior
      assert html =~ "swagger-ui", "Expected response to include swagger-ui component"
      assert html =~ "<title>Swagger UI</title>", "Expected page to have Swagger UI title"
    end)
  end

  test "includes swagger json link", %{conn: conn} do
    # Ensure ETS tables exist before making API requests
    ensure_ets_tables_exist()
    
    # Use safely_execute_ets_operation for API requests
    XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
      conn = get(conn, ~p"/api/docs")
      html = html_response(conn, 200)

      # Verify the page contains a link to the swagger JSON - key functional behavior
      assert html =~ "api_spec_url.pathname = \"/api/docs/openapi.json\"", "Expected Swagger UI to load the OpenAPI spec from /api/docs/openapi.json"
    end)
  end

  test "swagger UI includes required scripts", %{conn: conn} do
    # Ensure ETS tables exist before making API requests
    ensure_ets_tables_exist()
    
    # Use safely_execute_ets_operation for API requests
    XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
      conn = get(conn, ~p"/api/docs")
      html = html_response(conn, 200)

      # Verify the UI has the required JS scripts - key functional dependencies
      assert html =~ "swagger-ui.css", "Expected Swagger UI CSS to be included"
      assert html =~ "swagger-ui-bundle.js", "Expected Swagger UI bundle JS to be included"
      assert html =~ "swagger-ui-standalone-preset.js", "Expected Swagger UI preset JS to be included"
    end)
  end

  test_with_mock "serves openapi.json with valid JSON", %{conn: conn}, File, [], 
    [read: fn(_) -> {:ok, valid_swagger_json()} end] do
    
    # Ensure ETS tables exist before making API requests
    ensure_ets_tables_exist()
    
    # Use safely_execute_ets_operation for API requests
    XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
      conn = get(conn, ~p"/api/docs/openapi.json")
      
      # Verify content type is JSON - key behavior
      content_type = Enum.find_value(conn.resp_headers, "", fn
        {"content-type", value} -> value
        _ -> false
      end)
      assert content_type =~ "application/json", "Expected JSON content type for OpenAPI spec"
      assert conn.status == 200, "Expected successful response"
      
      # Parse response to verify it's valid JSON
      {:ok, json} = Jason.decode(conn.resp_body)
      assert is_map(json), "Expected response to be a valid JSON object"
      
      # Verify key API spec components - focus on structure
      assert json["swagger"] == "2.0", "Expected OpenAPI version 2.0"
      assert json["info"]["title"] == "XIAM API", "Expected API title 'XIAM API'"
      assert json["paths"] != nil, "Expected API spec to include paths section"
    end)
  end

  test_with_mock "returns 404 when api spec file not found", %{conn: conn}, File, [],
    [read: fn(_) -> {:error, :enoent} end] do
    
    # Ensure ETS tables exist before making API requests
    ensure_ets_tables_exist()
    
    # Use safely_execute_ets_operation for API requests
    XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
      conn = get(conn, ~p"/api/docs/openapi.json")
      
      # Verify error response behavior
      assert conn.status == 404, "Expected 404 Not Found when OpenAPI spec file is missing"
      assert json_response(conn, 404)["error"] == "API specification file not found", "Expected specific error message for missing file"
    end)
  end

  test_with_mock "returns 500 when api spec has invalid JSON", %{conn: conn}, File, [],
    [read: fn(_) -> {:ok, "invalid json content"} end] do
    
    # Ensure ETS tables exist before making API requests
    ensure_ets_tables_exist()
    
    # Use safely_execute_ets_operation for API requests
    XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
      conn = get(conn, ~p"/api/docs/openapi.json")
      
      # Verify error handling behavior
      assert conn.status == 500, "Expected 500 Internal Server Error for invalid JSON"
      assert json_response(conn, 500)["error"] == "Invalid JSON format in API specification", "Expected specific error message for invalid JSON"
    end)
  end
  
  # Helper function to generate valid swagger JSON for tests
  defp valid_swagger_json do
    Jason.encode!(%{
      "swagger" => "2.0",
      "info" => %{
        "title" => "XIAM API",
        "version" => "1.0.0"
      },
      "basePath" => "/api",
      "paths" => %{
        "/api/auth/login" => %{},
        "/api/users" => %{},
        "/api/health" => %{}
      },
      "definitions" => %{}
    })
  end
end
