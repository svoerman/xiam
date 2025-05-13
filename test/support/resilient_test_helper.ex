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
  
  * `:max_attempts` - Maximum number of retry attempts (default: 3)
  * `:delay_ms` - Initial delay in milliseconds between retries (default: 100)
  * `:backoff_factor` - Factor to increase delay between retries (default: 2.0)
  * `:jitter` - Random jitter to add to delay between retries (default: 0.1)
  * `:silent` - Whether to suppress error logging (default: false)
  
  ## Examples
  
      safely_execute_db_operation(fn ->
        Repo.insert(%User{name: "test"})
      end)
  """
  def safely_execute_db_operation(operation_fun, options \\ []) do
    # Default options
    max_attempts = Keyword.get(options, :max_attempts, 3)
    delay_ms = Keyword.get(options, :delay_ms, 100)
    backoff_factor = Keyword.get(options, :backoff_factor, 2.0)
    jitter = Keyword.get(options, :jitter, 0.1)
    silent = Keyword.get(options, :silent, false)
    
    # Safely checkout sandbox; swallow errors if repo is down
    try do
      Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo)
    rescue
      _ -> :ok
    catch
      :exit, _ -> :ok
    end
    # Safely set shared mode; swallow errors if repo is down
    try do
      Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
    rescue
      _ -> :ok
    catch
      :exit, _ -> :ok
    end
    
    # Execute with retries under sandbox ownership
    raw_result = safely_execute_with_retries(operation_fun, max_attempts, delay_ms, backoff_factor, jitter, silent, 1)
    # Return raw results; keep {:ok, _} and {:error, _} intact
    case raw_result do
      {:ok, _} -> raw_result
      {:error, _} -> raw_result
      other -> {:ok, other}
    end
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
  defp safely_execute_with_retries(operation_fun, max_attempts, delay_ms, backoff_factor, jitter, silent, attempt) do
    try do
      operation_fun.()
    catch
      _kind, error when attempt <= max_attempts ->
        # Only log detailed errors in non-silent mode and at a reasonable frequency
        cond do
          silent -> :ok  # Don't log anything in silent mode
          # Handle specific expected errors without logging to avoid cluttering test output
          is_exception_we_expect_to_retry?(error) -> :ok
          # Log other errors we're retrying for debugging purposes
          true -> 
            # Use Logger.debug rather than IO.inspect for better structured logs
            require Logger
            Logger.debug("Retrying operation (#{attempt}/#{max_attempts}): #{inspect_error_concisely(error)}")
        end
        
        # Calculate delay with exponential backoff and jitter
        actual_delay = round(delay_ms * :math.pow(backoff_factor, attempt - 1))
        jitter_amount = round(actual_delay * jitter * :rand.uniform())
        final_delay = actual_delay + jitter_amount
        
        # Add a delay before retrying that increases with each attempt
        Process.sleep(final_delay)
        
        # Retry the operation
        safely_execute_with_retries(
          operation_fun, 
          max_attempts, 
          delay_ms, 
          backoff_factor, 
          jitter, 
          silent, 
          attempt + 1
        )
        
      _kind, error ->
        # Max retries exceeded or uncaught error
        cond do
          silent -> {:error, error}  # Return error without logging in silent mode
          is_exception_we_expect_to_handle?(error) -> {:error, error}  # Quietly handle expected exceptions 
          true ->
            # Only log truly unexpected errors or when we've run out of retries
            require Logger
            Logger.warning("Operation failed after #{attempt} attempts: #{inspect_error_concisely(error)}")
            {:error, error}
        end
    end
  end
  
  # Helper function to check if an error is an expected one that we regularly retry
  # These errors are so common during tests that we don't want to log them
  defp is_exception_we_expect_to_retry?(error) do
    cond do
      # Database unique constraint violations are common in tests with retries
      match?(%Postgrex.Error{postgres: %{code: :unique_violation}}, error) -> true
      # Ecto changeset errors for unique constraints are expected
      match?({:error, %Ecto.Changeset{errors: _}}, error) -> true
      # DBConnection ownership errors are expected when connections cross processes
      match?(%DBConnection.OwnershipError{}, error) -> true
      # Common assertion errors during retries
      match?(%ExUnit.AssertionError{}, error) -> true
      true -> false
    end
  end
  
  # Helper function to check if an error is one we expect to handle without warning
  # These are errors we expect to happen and have handled appropriately
  defp is_exception_we_expect_to_handle?(error) do
    is_exception_we_expect_to_retry?(error)
  end
  
  # Helper function to make error messages more concise for logging
  defp inspect_error_concisely(error) do
    case error do
      %Postgrex.Error{postgres: %{code: code, message: message}} ->
        "Postgres error: #{code} - #{message}"
      {:error, %Ecto.Changeset{errors: errors}} ->
        "Changeset error: #{inspect(errors)}"
      # Add more specific error formatting as needed
      _ -> 
        # Limit the size of the error message for large errors
        error_str = inspect(error, limit: 5)
        if String.length(error_str) > 200 do
          String.slice(error_str, 0, 197) <> "..."
        else
          error_str
        end
    end
  end
end
