# Only define this module if it hasn't been defined yet
# This prevents redefining module warnings during test runs
unless Code.ensure_loaded?(XIAM.ObanTestHelper) do
  defmodule XIAM.ObanTestHelper do
    @moduledoc """
    Helper module for safely using Oban in tests.
    A simplified version that provides just the basic tracking functionality.
    """
    
    # Simple in-memory tracking of Oban jobs for testing
    @doc """
    Track a job that would have been created in the test environment.
    This is a simple mock function used by worker modules in test mode.
    """
    def track_job(worker, args) do
      require Logger
      Logger.debug("TEST MODE: Oban job tracked - Worker: #{worker}, Args: #{inspect(args)}")
      :ok
    end
    
    @doc """
    Create a mock Oban job struct for testing purposes.
    """
    def mock_job(args \\ %{}) do
      %Oban.Job{
        id: System.unique_integer([:positive]),
        args: args,
        state: "available",
        queue: "test",
        worker: "TestWorker",
        attempt: 1,
        max_attempts: 3,
        inserted_at: DateTime.utc_now(),
        scheduled_at: DateTime.utc_now()
      }
    end
  end
end