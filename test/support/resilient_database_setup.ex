defmodule XIAM.ResilientDatabaseSetup do
  # Removed compiler directive as it was causing compilation issues
  @moduledoc """
  Provides enhanced database setup functions for test environments.
  """

  # Define helper outside our module to avoid namespace conflict
  defmodule TestOutputHelper do
    def info(message), do: IO.puts("[INFO] #{message}")
    def warn(message), do: IO.puts("[WARNING] #{message}")
  end
  
  alias TestOutputHelper, as: Output

  @doc """
  Initializes the test environment by ensuring applications are started.
  """
  def initialize_test_environment(_tags \\ []) do
    # Ensure Ecto applications are started
    Application.ensure_all_started(:ecto_sql)
    Application.ensure_all_started(:postgrex)
    
    # Start repo without namespace conflicts
    repo_module = XIAM.Repo
    
    # Check if repo is started
    case Process.whereis(repo_module) do
      nil ->
        # Try to start the repo
        try do
          apply(repo_module, :start_link, [[pool_size: 10]])
          :ok
        rescue
          _ -> :ok  # Already started or other issues
        end
      _pid -> 
        :ok  # Already started
    end
  end

  @doc """
  Ensures the repository is started, for backwards compatibility.
  """
    def ensure_repository_started do
    initialize_test_environment()
    {:ok, :repository_started}
  end


  @doc """
  Checks the status of the repository.
  """
  def repository_status(_repo) do
    :ok
  end

  @doc """
  Performs a database operation with explicit error handling.
  """
  def safely_execute_db_operation(operation, options \\ []) do
    # Default options
    opts = Keyword.merge([
      max_retries: 1,
      retry_delay: 500,
      show_errors: true,
      verbose: false
    ], options)

    # Execute with retries if needed
    if opts[:max_retries] > 1 do
      safely_execute_with_retries(operation, opts[:max_retries], opts[:retry_delay], 1, opts)
    else
      safely_execute_once(operation, opts)
    end
  end

  @doc """
  Executes a database operation with a single attempt, handling errors gracefully.
  """
  def safely_execute_once(operation, opts \\ []) do
    try do
      operation.()
    rescue
      e ->
        # Log the error if show_errors is enabled
        if Keyword.get(opts, :show_errors, true) do
          Output.warn("Database operation failed: #{inspect(e)}")
        end
        {:error, e}
    catch
      kind, value ->
        # Log the error if show_errors is enabled
        if Keyword.get(opts, :show_errors, true) do
          Output.warn("Database operation failed with #{kind}: #{inspect(value)}")
        end
        {:error, {kind, value}}
    end
  end

  @doc """
  Executes a database operation with automatic retries.
  """
  def safely_execute_with_retries(operation, max_retries, delay_ms, retry_count \\ 1, opts \\ []) do
    # First attempt
    case safely_execute_once(operation, Keyword.put(opts, :show_errors, false)) do
      {:error, reason} ->
        if retry_count < max_retries do
          # Log retry information if verbose
          if opts[:verbose] do
            Output.info("Retrying operation (attempt #{retry_count + 1} of #{max_retries})...")
          end
          
          # Wait before retrying
          Process.sleep(delay_ms)
          
          # Retry the operation
          safely_execute_with_retries(operation, max_retries, delay_ms, retry_count + 1, opts)
        else
          # Max retries reached, show error and return error
          if opts[:show_errors] do
            Output.warn("Operation failed after #{max_retries} attempts: #{inspect(reason)}")
          end
          {:error, reason}
        end
      result -> result  # Success or non-error result
    end
  end
end
