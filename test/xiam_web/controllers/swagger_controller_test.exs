defmodule XIAMWeb.SwaggerControllerTest do
  use XIAMWeb.ConnCase
  import Mock
  import Phoenix.ConnTest

  test "renders swagger UI page", %{conn: conn} do
    conn = get(conn, ~p"/api/docs")
    html = html_response(conn, 200)

    # Verify the page contains swagger UI
    assert html =~ "swagger-ui"
    assert html =~ "<title>Swagger UI</title>"
  end

  test "includes swagger json link", %{conn: conn} do
    conn = get(conn, ~p"/api/docs")
    html = html_response(conn, 200)

    # Verify the page contains a link to the swagger JSON
    assert html =~ "api_spec_url.pathname = \"/api/docs/openapi.json\""
  end

  test "swagger UI includes required scripts", %{conn: conn} do
    conn = get(conn, ~p"/api/docs")
    html = html_response(conn, 200)

    # Verify the UI has the required JS scripts
    assert html =~ "swagger-ui.css"
    assert html =~ "swagger-ui-bundle.js"
    assert html =~ "swagger-ui-standalone-preset.js"
  end

  test_with_mock "serves openapi.json with valid JSON", %{conn: conn}, File, [], 
    [read: fn(_) -> {:ok, valid_swagger_json()} end] do
    
    conn = get(conn, ~p"/api/docs/openapi.json")
    
    # Verify content type is JSON
    content_type = Enum.find_value(conn.resp_headers, "", fn
      {"content-type", value} -> value
      _ -> false
    end)
    assert content_type =~ "application/json"
    assert conn.status == 200
    
    # Parse response to verify it's valid JSON
    {:ok, json} = Jason.decode(conn.resp_body)
    assert is_map(json)
  end

  test_with_mock "returns 404 when api spec file not found", %{conn: conn}, File, [],
    [read: fn(_) -> {:error, :enoent} end] do
    
    conn = get(conn, ~p"/api/docs/openapi.json")
    
    # Verify error response
    assert conn.status == 404
    assert json_response(conn, 404)["error"] == "API specification file not found"
  end

  test_with_mock "returns 500 when api spec has invalid JSON", %{conn: conn}, File, [],
    [read: fn(_) -> {:ok, "invalid json content"} end] do
    
    conn = get(conn, ~p"/api/docs/openapi.json")
    
    # Verify error response
    assert conn.status == 500
    assert json_response(conn, 500)["error"] == "Invalid JSON format in API specification"
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
