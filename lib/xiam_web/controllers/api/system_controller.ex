defmodule XIAMWeb.API.SystemController do
  use XIAMWeb, :controller
  alias XIAM.System.Health

  @doc """
  Get the system health status.
  This endpoint provides basic health information without authentication
  for monitoring and health checking.
  """
  def health(conn, _params) do
    # Only collect basic health info for the public endpoint
    health_data = %{
      status: "ok",
      version: Application.spec(:xiam, :vsn) || "Unknown",
      environment: Application.get_env(:xiam, :env) || Mix.env(),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    json(conn, health_data)
  end

  @doc """
  Get detailed system status.
  This endpoint requires authentication and provides complete system information.
  """
  def status(conn, _params) do
    # This action is protected by the APIAuthPlug and APIAuthorizePlug
    # so only authenticated users with proper capabilities can access it
    health_data = Health.check_health()
    
    # Convert memory values to MB for better readability
    memory_data = Map.new(health_data.memory, fn {k, v} -> 
      case is_integer(v) do
        true -> {k, Float.round(v / 1_048_576, 2)}
        false -> {k, v} # Keep original value if not a number
      end
    end)
    health_data = Map.put(health_data, :memory, memory_data)
    
    json(conn, health_data)
  end
end
