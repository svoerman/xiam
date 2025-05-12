defmodule XIAM.Hierarchy.NodeMovementHelper do
  @moduledoc """
  Helper module for resilient node movement operations in tests.
  
  Addresses common issues with hierarchy node movement that can cause
  flaky tests, including:
  - ID type mismatches (string vs integer)
  - Database connectivity issues
  - Cache consistency issues
  """
  
  alias XIAM.Hierarchy.NodeManager
  alias XIAM.Hierarchy.IDTypeHelper
  alias XIAM.Cache.HierarchyCache
  
  @doc """
  Safely moves a node to a new parent, handling type conversions and ensuring resilience.
  
  Returns {:ok, result} if the operation completed successfully, or
  {:error, reason} if it failed but was properly handled.
  
  ## Options
    * `:retry` - Number of retry attempts (default: 3)
    * `:delay_ms` - Delay between retries in milliseconds (default: 100)
    * `:invalidate_cache` - Whether to invalidate cache after move (default: true)
  """
  def safely_move_node(node_id, new_parent_id, opts \\ []) do
    # Ensure IDs are integers to prevent type mismatch errors
    safe_node_id = IDTypeHelper.ensure_integer_id(node_id)
    safe_parent_id = IDTypeHelper.ensure_integer_id(new_parent_id)
    
    # Extract options
    retries = Keyword.get(opts, :retry, 3)
    delay_ms = Keyword.get(opts, :delay_ms, 100)
    invalidate_cache = Keyword.get(opts, :invalidate_cache, true)
    
    # Perform the move operation with resilient execution
    result = XIAM.ResilientTestHelper.safely_execute_db_operation(
      fn -> 
        NodeManager.move_node(safe_node_id, safe_parent_id)
      end,
      retry: retries,
      retry_delay: delay_ms
    )
    
    # Invalidate cache if requested and operation succeeded
    if invalidate_cache do
      # Use another resilient operation for cache invalidation
      XIAM.ResilientTestHelper.safely_execute_db_operation(
        fn -> HierarchyCache.invalidate_all() end,
        retry: 2,
        retry_delay: 50
      )
      
      # Small delay to allow cache to update
      :timer.sleep(50)
    end
    
    # Return the result
    case result do
      {:ok, move_result} -> {:ok, move_result}
      {:error, %Ecto.ChangeError{message: _message}} ->
        # ID type mismatch encountered in move operation
        
        # Return a properly formatted error
        {:error, :id_type_mismatch}
      other_error -> other_error
    end
  end
  
  @doc """
  Verify access after node movement, with resilient error handling.
  
  This helper provides consistent access checking after node movement,
  which is a common source of flaky tests due to caching and timing issues.
  """
  def verify_access_after_move(user_id, node_id, expected_result, opts \\ []) do
    # Ensure IDs are integers
    safe_user_id = IDTypeHelper.ensure_integer_id(user_id)
    safe_node_id = IDTypeHelper.ensure_integer_id(node_id)
    
    # Extract options
    retries = Keyword.get(opts, :retry, 3)
    delay_ms = Keyword.get(opts, :delay_ms, 100)
    
    # Force cache invalidation first to ensure we don't get stale data
    XIAM.ResilientTestHelper.safely_execute_db_operation(
      fn -> XIAM.Cache.HierarchyCache.invalidate_all() end,
      retry: 2
    )
    
    # Small delay to allow cache to update
    :timer.sleep(delay_ms)
    
    # Try multiple times with increasing delays to handle eventual consistency
    Enum.reduce_while(1..retries, nil, fn attempt, _ -> 
      # Invalidate cache again before each check
      XIAM.ResilientTestHelper.safely_execute_db_operation(
        fn -> XIAM.Cache.HierarchyCache.invalidate_all() end,
        retry: 2
      )
      
      # Wait with increasing delay between attempts
      :timer.sleep(attempt * delay_ms) 
      
      # Check access status
      access_status = XIAM.ResilientTestHelper.safely_execute_db_operation(
        fn -> XIAM.Hierarchy.AccessManager.check_access(safe_user_id, safe_node_id) end,
        retry: 2
      )
      
      # If we get the expected result, we can stop checking
      if access_matches_expectation?(access_status, expected_result) do
        {:halt, access_status}
      else
        # If we're on the last attempt, return whatever we got
        if attempt == retries do
          {:halt, access_status}
        else
          {:cont, access_status}
        end
      end
    end)
  end
  
  # Helper to check if access result matches expectation
  defp access_matches_expectation?(access_result, expected) do
    case {access_result, expected} do
      # Simple boolean cases
      {true, true} -> true
      {false, false} -> true
      {nil, false} -> true  # nil is interpreted as no access
      
      # Complex map result cases
      {{:ok, %{has_access: has_access}}, expected_access} when is_boolean(expected_access) ->
        has_access == expected_access
        
      {%{has_access: has_access}, expected_access} when is_boolean(expected_access) ->
        has_access == expected_access
        
      # Any other case doesn't match expectation
      _ -> false
    end
  end
end
