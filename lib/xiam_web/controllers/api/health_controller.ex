defmodule XIAMWeb.API.HealthController do
  @moduledoc """
  Controller for health check endpoints.

  Provides a simple health check endpoint for the API.
  Returns basic information about the system's health status.
  """
  
  use XIAMWeb, :controller
  use OpenApiSpex.ControllerSpecs
  
  alias XIAMWeb.Schemas.HealthResponse
  
  @doc """
  Provides a simple health check endpoint for the API.
  Returns basic information about the system's health status.
  """
  # Use the operation/2 macro/function provided by ControllerSpecs
  operation :index, # Action name atom
    # Keyword list with operation details
    summary: "Simple health check endpoint",
    description: "Returns a simple 200 OK with current status and version.",
    tags: ["Health"], # Add a tag for grouping in Swagger UI
    responses: %{
      # Use the tuple format: {description, content_type, schema}
      200 => {"OK", "application/json", HealthResponse.Response}
    }
  def index(conn, _params) do
    # Get application version from mix.exs
    version = Application.spec(:xiam, :vsn) |> to_string()
    
    # Get current timestamp in ISO8601 format
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    
    conn
    |> put_status(200)
    |> json(%{
      status: "ok",
      version: version,
      timestamp: timestamp
    })
  end
  
  @doc """
  Additional health endpoint for detailed system health.
  """
  def health(conn, _params) do
    # Get application version
    version = Application.spec(:xiam, :vsn) |> to_string()
    
    # Get current timestamp in ISO8601 format 
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    
    # Check database connection
    db_status = case XIAM.Repo.query("SELECT 1") do
      {:ok, _} -> "connected"
      _ -> "error"
    end
    
    # Get some basic system metrics
    memory_usage = :erlang.memory()
    process_count = :erlang.system_info(:process_count)
    system_architecture = :erlang.system_info(:system_architecture) |> to_string()
    uptime_ms = :erlang.statistics(:wall_clock) |> elem(0)
    uptime_days = uptime_ms / (1000 * 60 * 60 * 24) |> Float.round(2)
    
    conn
    |> put_status(200)
    |> json(%{
      status: "ok",
      version: version,
      timestamp: timestamp,
      environment: Mix.env(),
      system: %{
        architecture: system_architecture,
        uptime_days: uptime_days,
        process_count: process_count,
        memory: %{
          total: memory_usage[:total],
          processes: memory_usage[:processes],
          atom: memory_usage[:atom],
          binary: memory_usage[:binary]
        }
      },
      database: %{
        status: db_status
      }
    })
  end
end