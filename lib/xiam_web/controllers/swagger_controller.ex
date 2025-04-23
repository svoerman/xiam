defmodule XIAMWeb.SwaggerController do
  use XIAMWeb, :controller
  
  def index(conn, _params) do
    # Create a simple static HTML page for Swagger UI
    swagger_html = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Swagger UI</title>
      <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui.css">
      <style>
        body {
          margin: 0;
          padding: 0;
          background-color: #fff;
          color: #3b4151;
        }
        .swagger-ui {
          background-color: #fff;
        }
        .swagger-ui .topbar {
          background-color: #1e293b;
          padding: 10px 0;
        }
        .swagger-ui .info .title {
          color: #1e293b;
        }
        .swagger-ui .opblock-tag {
          color: #1e293b;
          background-color: #f8fafc;
        }
        .swagger-ui .opblock .opblock-summary-operation-id, 
        .swagger-ui .opblock .opblock-summary-path, 
        .swagger-ui .opblock .opblock-summary-path__deprecated {
          color: #334155;
        }
        .swagger-ui .opblock .opblock-summary-description {
          color: #64748b;
        }
        .swagger-ui .scheme-container {
          background-color: #f8fafc;
        }
        .swagger-ui section.models {
          background-color: #f1f5f9;
        }
        .swagger-ui .btn {
          color: #1e293b;
        }
        .swagger-ui select {
          background-color: #fff;
          color: #1e293b;
        }
      </style>
    </head>
    <body>
      <div id="swagger-ui"></div>
      
      <script src="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui-bundle.js"></script>
      <script src="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui-standalone-preset.js"></script>
      <script>
        window.onload = function() {
          var api_spec_url = new URL(window.location);
          api_spec_url.pathname = "/api/docs/openapi.json";
          
          const ui = SwaggerUIBundle({
            url: api_spec_url.toString(),
            dom_id: '#swagger-ui',
            deepLinking: true,
            presets: [
              SwaggerUIBundle.presets.apis,
              SwaggerUIStandalonePreset
            ],
            plugins: [
              SwaggerUIBundle.plugins.DownloadUrl
            ],
            layout: "StandaloneLayout"
          });
          window.ui = ui;
        };
      </script>
    </body>
    </html>
    """
    
    conn
    |> put_root_layout(false)
    |> put_resp_content_type("text/html")
    |> send_resp(200, swagger_html)
  end
  
  def api_json(conn, _params) do
    # Read the Swagger JSON file directly
    json_path = Application.app_dir(:xiam, "priv/static/swagger/api-spec.json")
    
    case File.read(json_path) do
      {:ok, content} ->
        # Parse the JSON content
        case Jason.decode(content) do
          {:ok, _json} ->
            # Just serve the file directly
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, content)
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
