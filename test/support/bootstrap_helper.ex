defmodule XIAM.BootstrapHelper do
  @moduledoc """
  Helper module for addressing database bootstrap issues in tests.
  
  This module provides functions to handle the specific "failed to bootstrap types"
  error that occurs with Ecto database connections, especially in test environments
  with high concurrency or when connections are reused improperly.
  """
  
  @doc """
  Executes a database operation with protection against bootstrap errors.
  
  This function is specifically designed to handle the infamous
  "awaited on another connection that failed to bootstrap types" error
  that occurs in Ecto tests.
  
  It works by:
  1. Aggressively resetting the connection pool before the operation
  2. Executing the operation with proper connection checkout
  3. Handling any bootstrap errors with retry logic
  
  ## Options
  * `:max_retries` - Maximum number of retry attempts (default: 5)
  * `:delay_ms` - Delay between retries in milliseconds (default: 500)
  * `:reset_pool` - Whether to reset the connection pool before trying (default: true)
  
  ## Examples
      iex> XIAM.BootstrapHelper.safely_bootstrap(fn ->
      ...>   Repo.all(User)
      ...> end)
      {:ok, [%User{...}, ...]}
  """
  def safely_bootstrap(fun, opts \\ []) do
    max_retries = Keyword.get(opts, :max_retries, 5)
    delay_ms = Keyword.get(opts, :delay_ms, 500)
    reset_pool = Keyword.get(opts, :reset_pool, true)
    parent = Keyword.get(opts, :parent, self())
    
    safely_bootstrap(fun, max_retries, delay_ms, reset_pool, parent, 0)
  end
  
  defp safely_bootstrap(_fun, max_retries, _delay_ms, _reset_pool, _parent, attempts) 
       when attempts >= max_retries do
    {:error, :max_retries_exceeded}
  end
  
  defp safely_bootstrap(fun, max_retries, delay_ms, reset_pool, parent, attempts) do
    # Optionally reset the connection pool
    if reset_pool and attempts > 0 do
      reset_connection_pool()
    end
    
    # Ensure sandbox mode is properly configured
    try do
      # First set manual mode to ensure clean checkout
      Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, :manual)
      
      # Explicitly check out a connection
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo)
      
      # Allow the parent process to also use this connection
      # This is critical for test processes that span multiple functions
      if parent != self() do
        Ecto.Adapters.SQL.Sandbox.allow(XIAM.Repo, parent, self())
      end
      
      # Now set shared mode to allow child processes
      Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
      
      # Execute the operation with explicit sandbox ownership
      result = fun.()
      
      # Check in the connection when done
      Ecto.Adapters.SQL.Sandbox.checkin(XIAM.Repo)
      
      {:ok, result}
    rescue
      # Handle specific bootstrap error
      e in DBConnection.ConnectionError ->
        error_message = Exception.message(e)
        
        if String.contains?(error_message, "failed to bootstrap types") do
          # This is the error we're specifically looking for
          IO.puts("Bootstrap error detected (attempt #{attempts + 1}/#{max_retries}), resetting connection...")
          
          # Wait a bit before retrying
          Process.sleep(delay_ms)
          
          # Force a more aggressive reset for subsequent attempts
          safely_bootstrap(fun, max_retries, delay_ms, true, parent, attempts + 1)
        else
          # Some other connection error, just rethrow
          reraise e, __STACKTRACE__
        end
        
      # Handle ownership errors
      _e in DBConnection.OwnershipError ->
        IO.puts("Ownership error detected (attempt #{attempts + 1}/#{max_retries}), resetting ownership...")
        # Reset connection and retry with explicit ownership model
        reset_connection_pool()
        Process.sleep(delay_ms) 
        safely_bootstrap(fun, max_retries, delay_ms, true, parent, attempts + 1)
      
      # Catch other database-related errors that might benefit from retry
      _e in [Postgrex.Error, Ecto.StaleEntryError, Ecto.ConstraintError] ->
        IO.puts("Database error detected (attempt #{attempts + 1}/#{max_retries}), retrying...")
        Process.sleep(delay_ms)
        safely_bootstrap(fun, max_retries, delay_ms, true, parent, attempts + 1)
        
      # Let other errors pass through
      e ->
        reraise e, __STACKTRACE__
    end
  end
  
  @doc """
  Aggressively resets the connection pool to handle bootstrap issues.
  
  This function performs a complete reset of the Ecto connection pool:
  1. Stops the repository
  2. Forces checkout of all connections to release them
  3. Restarts the repository with a fresh pool
  
  Returns `:ok` if successful or an error tuple with diagnostics.
  """
  def reset_connection_pool do
    try do
      # Try to check in any connections first
      try do
        Ecto.Adapters.SQL.Sandbox.checkin(XIAM.Repo)
      rescue
        _ -> :ok
      end
      
      # Stop the repository
      case XIAM.Repo.stop() do
        :ok -> :ok
        {:error, {:not_found, _}} -> :ok
        err -> IO.puts("Warning: Failed to stop repo: #{inspect(err)}")
      end
      
      # Force garbage collection to help release connections
      :erlang.garbage_collect()
      
      # Wait a bit for connections to fully close
      Process.sleep(100)
      
      # Start the repository again
      start_result = 
        case XIAM.Repo.start_link() do
          {:ok, _} -> :ok
          {:error, {:already_started, _}} -> :ok
          error -> error
        end
      
      # Configure sandbox mode (defensive)
      configure_result =
        try do
          Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, :manual)
          :ok
        rescue
          e -> {:error, e}
        end
      
      # Return overall result
      case {start_result, configure_result} do
        {:ok, :ok} -> :ok
        error -> {:error, error}
      end
    rescue
      e -> {:error, e}
    end
  end
  
  @doc """
  Executes a test case with bootstrap protection.
  
  This function wraps a test case to ensure proper database setup and cleanup:
  1. Resets the connection pool before the test
  2. Sets up sandbox mode and checks out a connection
  3. Runs the test with proper error handling
  4. Checks in the connection after the test
  
  Returns the result of the test case or an error tuple.
  """
  def with_bootstrap_protection(test_case) do
    try do
      # Reset the connection pool
      reset_connection_pool()
      
      # Set up sandbox and check out a connection
      Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
      
      # Execute the test case
      result = test_case.()
      
      # Clean up
      Ecto.Adapters.SQL.Sandbox.checkin(XIAM.Repo)
      
      # Return the result
      {:ok, result}
    rescue
      e -> {:error, {e, __STACKTRACE__}}
    end
  end
end
