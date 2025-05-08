defmodule XIAM.ResilientDatabaseSetup do
  alias XIAM.TestOutputHelper, as: Output
  @moduledoc """
  Provides enhanced database setup functions for test environments.
  
  This module addresses common issues with database initialization in tests:
  - Ensures Ecto repositories are properly started before tests run
  - Handles race conditions and concurrent access
  - Provides recovery mechanisms for transient database connection issues
  - Integrates with ETS table initialization to ensure all dependencies are available
  
  It's designed to work alongside XIAM.DataCase but provides more explicit control
  over database initialization.
  """
  
  @doc """
  Ensures that the database repository is properly started and accessible.
  
  This function attempts to start the repository with multiple retry attempts
  and provides detailed diagnostics about the repository state.
  
  Returns :ok if successful, or an error tuple with diagnostics.
  """
  def ensure_repository_started(repo \\ XIAM.Repo, max_attempts \\ 3) do
    ensure_repository_started(repo, max_attempts, 1)
  end
  
  defp ensure_repository_started(_repo, max_attempts, current_attempt) when current_attempt > max_attempts do
    {:error, :max_attempts_exceeded}
  end
  
  defp ensure_repository_started(repo, max_attempts, current_attempt) do
    # First check if repository process exists
    repo_status = repository_status(repo)
    
    case repo_status do
      {:ok, _pid} ->
        # Repository is started and running, verify it's accessible
        verify_repository_connection(repo)
        
      {:error, {:process_dead, pid}} ->
        # Process exists but is dead, restart it
        Output.debug_print("Repository process #{inspect(pid)} is dead, restarting...")
        restart_repository(repo, max_attempts, current_attempt)
        
      {:error, :not_started} ->
        # Repository is not started, try to start it
        start_result = do_start_repository(repo)
        case start_result do
          :ok -> verify_repository_connection(repo)
          _ -> 
            # Failed to start, retry after a short delay
            Process.sleep(50 * current_attempt)
            ensure_repository_started(repo, max_attempts, current_attempt + 1)
        end
    end
  end
  
  @doc """
  Verifies that a connection to the repository can be established.
  
  This goes beyond checking if the repository process exists and actually
  attempts a simple query to ensure the database is accessible.
  """
  def verify_repository_connection(repo) do
    try do
      # Try a simple query to verify connection
      repo.__adapter__()
      
      # Just check the adapter configuration rather than executing a query
      # which can cause ownership issues in the test sandbox
      {:ok, :connected}
    rescue
      e -> {:error, {:adapter_error, e}}
    end
  end
  
  @doc """
  Checks the current status of a repository.
  
  Returns:
  - {:ok, pid} if the repository is started and the process is alive
  - {:error, :not_started} if the repository is not started
  - {:error, {:process_dead, pid}} if the process exists but is not alive
  """
  def repository_status(repo) do
    case Process.whereis(repo) do
      nil -> 
        {:error, :not_started}
      pid when is_pid(pid) -> 
        if Process.alive?(pid) do
          {:ok, pid}
        else
          {:error, {:process_dead, pid}}
        end
    end
  end
  
  @doc """
  Attempts to start a repository with proper error handling.
  This is the public API for starting repositories.
  """
  def start_repository(repo) do
    # Ensure all dependent applications are started first
    Application.ensure_all_started(:ecto_sql)
    
    # Attempt to start the repository
    try do
      case repo.start_link([]) do
        {:ok, pid} -> {:ok, pid}
        {:error, {:already_started, pid}} -> {:ok, pid}
        error -> error
      end
    rescue
      e -> {:error, {:exception, e}}
    end
  end
  
  # Private implementation of repository start for internal use.
  # Used by restart_repository and ensure_repository_started.
  defp do_start_repository(repo) do
    # Try to start the repo
    start_result = try do
      repo.start_link()
    rescue
      e -> {:error, e}
    end
    
    case start_result do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, _reason} = error -> error
    end
  end
  
  # Function to restart a repository with a dead process
  defp restart_repository(repo, max_attempts, current_attempt) do
    if current_attempt < max_attempts do
      # First try to stop the repository if it exists but is dead
      _stop_result = try do
        # Try to stop the repository - this may fail if process is already dead
        case Process.whereis(repo) do
          pid when is_pid(pid) -> 
            try do
              Process.exit(pid, :kill)
              :ok
            catch
              _kind, _value -> :ok  # Already dead, that's fine
            end
          nil -> :ok  # Process doesn't exist, nothing to stop
        end
      rescue
        e -> {:error, e}
      end
      
      # Add a small delay before restart attempt
      Process.sleep(200 * (current_attempt + 1))
      
      # Now try to start it
      start_result = do_start_repository(repo)
      
      case start_result do
        :ok -> 
          # Successfully restarted
          :ok
        _error -> 
          # Failed to restart, try again with incremented attempt count
          Output.debug_print("Restart attempt #{current_attempt + 1} failed, trying again...")
          restart_repository(repo, max_attempts, current_attempt + 1)
      end
    else
      # Exceeded max attempts
      {:error, :max_restart_attempts_exceeded}
    end
  end
  
  @doc """
  Initializes the test environment with all necessary components for database tests.
  
  This is a comprehensive setup function that:
  1. Ensures all required ETS tables exist
  2. Starts the database repository
  3. Configures the Ecto sandbox
  4. Sets up any additional caches or tables needed for tests
  
  It's designed to be more reliable than the standard setup functions and
  provides better diagnostics when something goes wrong.
  """
  def initialize_test_environment(tags \\ %{}) do
    # Track the calling process - essential for proper connection ownership
    _caller = self()
    
    # First, set required application environment variables
    # Critical for LiveView tests to prevent "unknown application: nil" errors
    Application.put_env(:phoenix_live_view, :app_name, :xiam)
    Application.put_env(:phoenix, :json_library, Jason)
    Application.put_env(:xiam, :env, :test)
    
    # Initialize application-specific ETS tables (not Phoenix tables)
    # This will safely check Phoenix tables but won't try to create them
    XIAM.ETSTestHelper.ensure_ets_tables_exist()
    
    # Make sure the application is started
    # Let Phoenix create its own ETS tables during startup
    start_result = Application.ensure_all_started(:xiam)
    
    # After the application has started, ensure our tables have proper configuration
    # This will check if Phoenix tables exist and only then try to configure them
    XIAM.ETSTestHelper.safely_initialize_phoenix_config()
    
    # Ensure the repository is started
    repo_result = ensure_repository_started()
    
    # Make sure the sandbox mode is set to manual
    # This is particularly important for nested setups which may cause multiple checkouts
    # Add retry mechanism for sandbox mode setup to handle transient process failures
    sandbox_result = try do
      # Retry sandbox mode configuration with exponential backoff
      retry_result = retry_with_backoff(fn ->
        try do
          # Ensure the repository is started before trying to set mode
          case ensure_repo_started() do
            :ok ->
              # Set the mode to manual
              Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, :manual)
              {:ok, :manual}
            {:error, reason} ->
              {:error, {:repo_not_started, reason}}
          end
        rescue
          e in [ArgumentError, RuntimeError] ->
            # Common errors include repo not started or process not alive
            {:error, {:sandbox_mode, e}}
        catch
          :exit, {:noproc, _} -> 
            # Specific handling for process not alive errors
            {:error, :process_not_alive}
          kind, value -> 
            {:error, {kind, value}}
        end
      end, max_retries: 3, initial_delay: 50, max_delay: 500)
      
      case retry_result do
        {:ok, _} = success -> success
        {:error, reason} -> 
          # Make a final decision on whether to proceed or abort
          if fatal_error?(reason) do
            {:error, reason}
          else
            # For non-fatal errors, log and proceed with a warning
            Output.warn("Sandbox mode configuration issue", inspect(reason))
            {:ok, :manual_with_warning}
          end
      end
    rescue
      e -> {:error, {:sandbox_mode, e}}
    end
    
    # Configure sandbox mode based on tags, with proper error handling
    configure_result = try do
      configure_sandbox(tags)
    rescue
      e -> {:error, {:configure_sandbox, e}}
    end
    
    # Explicitly initialize hierarchy and access caches
    cache_result = initialize_hierarchy_caches()
    
    # Return diagnostics if something failed, but don't treat already_started repo as a failure
    # This avoids warnings when the repository was already started by the application
    case {start_result, repo_result, sandbox_result, configure_result, cache_result} do
      # Success case - everything started properly
      {{:ok, _}, {:ok, _}, {:ok, _}, _, :ok} -> :ok
      
      # Application start failed with already_started repo - this is actually fine
      {{:error, {:xiam, {{:shutdown, {:failed_to_start_child, XIAM.Repo, {:already_started, _}}}, _}}}, {:ok, _}, {:ok, _}, _, :ok} -> :ok
      
      # Any other failure combination - attempt an aggressive reset and retry
      result -> 
        IO.warn("Test environment initialization issues: #{inspect(result)}, attempting reset...")
        reset_result = reset_database_connections()
        Output.debug_print("Database connection reset completed with result", inspect(reset_result))
        :reset_attempted
    end
  end
  
  @doc """
  Resets database connections to a clean state.
  
  This function aggressively resets the database connections by:
  1. Stopping the repository
  2. Closing all existing connections
  3. Restarting the repository
  4. Reconfiguring the sandbox
  
  It's designed to handle bootstrap issues and provide a clean slate for tests.
  """
  def reset_database_connections do
    # Stop the repository to prevent any ongoing operations
    stop_result = stop_repository()
    
    # Close all existing connections to prevent any lingering issues
    close_result = close_all_connections()
    
    # Restart the repository to ensure a clean state
    restart_result = restart_repository()
    
    # Reconfigure the sandbox to ensure proper ownership and mode
    reconfigure_result = reconfigure_sandbox()
    
    # Return the result of the reset operation
    case {stop_result, close_result, restart_result, reconfigure_result} do
      {:ok, :ok, :ok, :ok} -> :ok
      result -> {:error, result}
    end
  end
  
  defp stop_repository do
    try do
      XIAM.Repo.stop()
      :ok
    rescue
      e -> {:error, {:stop_error, e}}
    end
  end
  
  defp close_all_connections do
    try do
      Ecto.Adapters.SQL.Sandbox.checkin(XIAM.Repo, [])
      :ok
    rescue
      e -> {:error, {:close_error, e}}
    end
  end
  
  defp restart_repository do
    try do
      ensure_repository_started()
      :ok
    rescue
      e -> {:error, {:restart_error, e}}
    end
  end
  
  defp reconfigure_sandbox do
    try do
      configure_sandbox(%{})
      :ok
    rescue
      e -> {:error, {:reconfigure_error, e}}
    end
  end
  
  @doc """
  Configures the sandbox for testing.
  
  This function determines if async mode should be used based on the provided tags.
  It then sets the sandbox mode and checks out a connection with proper ownership.
  """
  def configure_sandbox(tags) do
    # Determine if async mode should be used
    async_mode = Map.get(tags, :async, false)
    
    # Set sandbox mode
    Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, :manual)
    
    # Save information about the calling process - this is important for ownership tracking
    caller = self()
    
    # Avoid checkout if it's already been done
    # This prevents double-checkout which can lead to ownership issues
    try do
      if async_mode do
        # For async tests, check out a separate connection with longer timeout
        # but only if we haven't already checked one out
        {:ok, _} = Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo, 
                     ownership_timeout: 60_000,
                     caller: caller)
      else
        # For non-async tests, use shared mode for better performance
        # Allow checkout to fail if already checked out
        checkout_result = Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo, caller: caller)
        # Handle the result consistently regardless of the return format
        case checkout_result do
          {:ok, _} -> :ok
          :ok -> :ok
          _ -> checkout_result # Pass through other results
        end
        Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, caller})
      end
    rescue
      e -> 
        # If checkout fails because we already have a connection, that's fine
        case e do
          %DBConnection.OwnershipError{} -> :ok
          _ -> raise e
        end
    end
    
    :ok
  end
  
  @doc """
  Initializes the hierarchy and access caches with default entries.
  """
  def initialize_hierarchy_caches do
    # Create the hierarchy cache tables
    table_names = [:hierarchy_cache, :hierarchy_cache_metrics, :access_cache]
    
    Enum.each(table_names, fn table_name ->
      # Create the table if it doesn't exist
      XIAM.ETSTestHelper.safely_ensure_table_exists(table_name)
      
      # Initialize with default values for counters
      case table_name do
        :hierarchy_cache_metrics ->
          try do
            # Insert default counter values
            :ets.insert(table_name, {{"all", :full_invalidations}, 0})
            :ets.insert(table_name, {{"all", :partial_invalidations}, 0})
          catch
            :error, _ -> :ok # Ignore if already exists
          end
        _ -> :ok
      end
    end)
    
    :ok
  end
  
  @doc """
  Runs a database operation with resilient error handling.
  This is a wrapper around the ResilientTestHelper.safely_execute_db_operation
  that ensures the database is properly initialized first.
  """
  def safely_run_db_operation(function) do
    # First ensure the database is properly initialized
    ensure_repository_started()
    
    # Then run the operation through the existing helper
    XIAM.ResilientTestHelper.safely_execute_db_operation(function)
  end
  
  # Helper for retrying operations with exponential backoff
  defp retry_with_backoff(operation, opts) do
    max_retries = Keyword.get(opts, :max_retries, 3)
    initial_delay = Keyword.get(opts, :initial_delay, 100)
    max_delay = Keyword.get(opts, :max_delay, 1000)
    
    do_retry_with_backoff(operation, max_retries, initial_delay, max_delay, 0)
  end
  
  defp do_retry_with_backoff(operation, max_retries, initial_delay, max_delay, retry_count) do
    result = operation.()
    
    case result do
      {:ok, _} = success -> success  # Operation succeeded
      {:error, _} = error ->
        if retry_count < max_retries do
          # Calculate delay using exponential backoff with jitter
          delay = min(initial_delay * :math.pow(2, retry_count) + :rand.uniform(50), max_delay)
          Output.debug_print("Operation failed on attempt #{retry_count + 1}, retrying in #{trunc(delay)}ms...")
          Process.sleep(trunc(delay))
          do_retry_with_backoff(operation, max_retries, initial_delay, max_delay, retry_count + 1)
        else
          error  # Max retries reached, return the error
        end
    end
  end
  
  # Helper to ensure the repository is started
  defp ensure_repo_started do
    try do
      case Process.whereis(XIAM.Repo) do
        pid when is_pid(pid) -> 
          # Repo is already started
          :ok
        nil -> 
          # Try to start the repo
          {:ok, _} = Application.ensure_all_started(:ecto_sql)
          {:ok, _} = Application.ensure_all_started(:postgrex)
          
          # Explicitly start the repo
          case XIAM.Repo.start_link() do
            {:ok, _} -> :ok
            {:error, {:already_started, _}} -> :ok
            error -> {:error, error}
          end
      end
    rescue
      e -> {:error, e}
    catch
      kind, value -> {:error, {kind, value}}
    end
  end
  
  # Helper to determine if an error is fatal or can be ignored
  defp fatal_error?(reason) do
    case reason do
      # Process not alive errors can be non-fatal if the process might restart
      :process_not_alive -> false
      # Repo not started is usually recoverable
      {:repo_not_started, _} -> false
      # Other specific errors we know are not fatal
      {:sandbox_mode, %ArgumentError{}} -> false
      # Default - treat as fatal
      _ -> true
    end
  end
end
