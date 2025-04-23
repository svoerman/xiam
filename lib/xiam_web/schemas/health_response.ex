defmodule XIAMWeb.Schemas.HealthResponse do
  @moduledoc """
  Schema for the health check response.
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  # Define the schema for the health check response
  defmodule Response do
    @moduledoc """
    Response schema for health check endpoint
    """
    require OpenApiSpex

    # Use the OpenApiSpex.schema/1 macro to define the schema
    OpenApiSpex.schema(%{
      title: "HealthResponse",
      description: "Response schema for health check endpoint",
      type: :object,
      properties: %{
        status: %Schema{type: :string, description: "Status of the API", example: "ok"},
        version: %Schema{type: :string, description: "API version", example: "0.1.0"},
        timestamp: %Schema{
          type: :string,
          description: "Current server timestamp",
          format: :"date-time",
          example: "2025-04-20T21:46:24Z"
        }
      },
      required: [:status, :version, :timestamp],
      example: %{
        "status" => "ok",
        "version" => "0.1.0",
        "timestamp" => "2025-04-20T21:46:24Z"
      }
    })
  end
end
