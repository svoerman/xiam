defmodule XIAMWeb.API.HealthController do
  @moduledoc """
  Controller for API health check.
  Provides a simple endpoint for checking API status.
  """
  
  use XIAMWeb, :controller
  
  @doc """
  Provides a simple health check endpoint for the API.
  """
  def index(conn, _params) do
    conn
    |> put_status(200)
    |> json(%{status: "ok", version: "1.0.0", timestamp: DateTime.utc_now()})
  end
end
