defmodule XIAMWeb.SwaggerControllerTest do
  use XIAMWeb.ConnCase

  test "renders swagger UI page", %{conn: conn} do
    conn = get(conn, ~p"/api/docs")
    html = html_response(conn, 200)

    # Verify the page contains swagger UI
    assert html =~ "swagger-ui"
    assert html =~ "SwaggerUI"
    assert html =~ "<title>API Documentation</title>"
  end

  test "includes swagger json link", %{conn: conn} do
    conn = get(conn, ~p"/api/docs")
    html = html_response(conn, 200)

    # Verify the page contains a link to the swagger JSON
    assert html =~ "url: \"/api/docs/swagger.json\""
  end

  @tag :skip
  test "serves swagger.json", %{conn: conn} do
    conn = get(conn, ~p"/api/docs/swagger.json")

    # Verify the response is JSON and contains expected swagger structure
    json = json_response(conn, 200)
    assert json["swagger"] == "2.0"
    assert json["info"]["title"] == "XIAM API"
    assert json["basePath"] == "/api"
    assert is_map(json["paths"])
  end

  @tag :skip
  test "swagger.json contains core paths", %{conn: conn} do
    conn = get(conn, ~p"/api/docs/swagger.json")

    # Verify the JSON contains essential API paths
    json = json_response(conn, 200)

    # Check for authentication endpoints
    assert json["paths"]["/api/auth/login"]

    # Check for users endpoints
    assert json["paths"]["/api/users"]

    # Check for health endpoint
    assert json["paths"]["/api/health"]
  end

  @tag :skip
  test "swagger.json has proper structure", %{conn: conn} do
    conn = get(conn, ~p"/api/docs/swagger.json")
    json = json_response(conn, 200)

    # Verify the JSON has proper swagger structure
    assert is_binary(json["swagger"])
    assert is_map(json["info"])
    assert is_map(json["paths"])
    assert is_map(json["definitions"]) or is_map(json["components"])
  end

  test "swagger UI includes required scripts", %{conn: conn} do
    conn = get(conn, ~p"/api/docs")
    html = html_response(conn, 200)

    # Verify the UI has the required JS scripts
    assert html =~ "swagger-ui.css"
    assert html =~ "swagger-ui-bundle.js"
    assert html =~ "swagger-ui-standalone-preset.js"
  end
end
