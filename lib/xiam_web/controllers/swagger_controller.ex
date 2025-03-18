defmodule XIAMWeb.SwaggerController do
  use XIAMWeb, :controller
  
  def index(conn, _params) do
    render(conn, :index, layout: false)
  end
  
  def api_json(conn, _params) do
    # Read the Swagger JSON file directly
    json_path = Application.app_dir(:xiam, "priv/static/swagger/api-spec.json")
    
    case File.read(json_path) do
      {:ok, content} ->
        # Parse the JSON content
        case Jason.decode(content) do
          {:ok, json} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, Jason.encode!(json))
          {:error, _reason} ->
            conn
            |> put_status(500)
            |> json(%{error: "Invalid JSON format in API specification"})
        end
      {:error, _reason} ->
        conn
        |> put_status(404)
        |> json(%{error: "API specification file not found"})
    end
  end
end
