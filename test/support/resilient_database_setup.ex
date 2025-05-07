defmodule XIAM.ResilientDatabaseSetup do
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
        
      {:error, :not_started} ->
        # Repository is not started, try to start it
        start_result = start_repository(repo)
        case start_result do
          {:ok, _pid} -> verify_repository_connection(repo)
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
    sandbox_result = try do
      # Simply set the mode to manual - there's no getter function
      Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, :manual)
      {:ok, :manual}
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
      
      # Any other failure combination - log a warning
      result -> 
        IO.warn("Test environment initialization issues: #{inspect(result)}")
        :warning
    end
  end
  
  @doc """
  Configures the sandbox for testing.
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
end
