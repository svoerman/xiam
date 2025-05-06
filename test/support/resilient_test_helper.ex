defmodule XIAM.ResilientTestHelper do
  @moduledoc """
  Provides resilient operation patterns for tests.
  
  This module implements patterns for making test operations more resilient
  by providing safe execution functions with appropriate fallbacks and error handling.
  These patterns help prevent test failures due to race conditions, temporary database
  issues, or ETS table problems during concurrent test execution.
  """

  @doc """
  Safely executes a database operation with retry logic and error handling.
  
  This function provides a resilient pattern for database operations in tests,
  which can be prone to transient failures in a CI environment or during 
  concurrent test execution.
  
  ## Options
  
  * `:max_retries` - Maximum number of retry attempts (default: 3)
  * `:retry_delay` - Delay in milliseconds between retries (default: 50)
  * `:silent` - Whether to suppress error logging (default: false)
  
  ## Examples
  
      safely_execute_db_operation(fn ->
        Repo.insert(%User{name: "test"})
      end)
  """
  def safely_execute_db_operation(operation_fun, options \\ []) do
    max_retries = Keyword.get(options, :max_retries, 3)
    retry_delay = Keyword.get(options, :retry_delay, 50)
    silent = Keyword.get(options, :silent, false)
    
    safely_execute_with_retries(operation_fun, max_retries, retry_delay, silent)
  end
  
  @doc """
  Safely executes an ETS operation with fallback and error handling.
  
  This function provides a resilient pattern for ETS table operations,
  which can fail during test initialization or due to tables being created
  or deleted during concurrent test execution.
  
  ## Options
  
  * `:fallback_value` - Value to return if the operation fails (default: nil)
  * `:silent` - Whether to suppress error logging (default: true)
  
  ## Examples
  
      safely_execute_ets_operation(fn ->
        :ets.lookup(MyTable, :key)
      end, fallback_value: [])
  """
  def safely_execute_ets_operation(operation_fun, options \\ []) do
    fallback_value = Keyword.get(options, :fallback_value, nil)
    silent = Keyword.get(options, :silent, true)
    
    try do
      operation_fun.()
    catch
      _kind, error ->
        unless silent do
          IO.warn("ETS operation failed: #{inspect(error)}")
        end
        fallback_value
    end
  end
  
  # Helper function for executing operations with retry logic
  defp safely_execute_with_retries(operation_fun, max_retries, retry_delay, silent, attempt \\ 1) do
    try do
      operation_fun.()
    catch
      _kind, error when attempt <= max_retries ->
        unless silent do
          IO.inspect("Operation failed on attempt #{attempt}/#{max_retries}: #{inspect(error)}")
        end
        
        # Add a small delay before retrying
        Process.sleep(retry_delay)
        
        # Retry the operation
        safely_execute_with_retries(operation_fun, max_retries, retry_delay, silent, attempt + 1)
        
      _kind, error ->
        # Max retries exceeded or uncaught error
        unless silent do
          IO.warn("Operation failed after #{attempt} attempts: #{inspect(error)}")
        end
        {:error, error}
    end
  end
end
