# Test Patterns in XIAM

This document outlines the testing patterns implemented in the XIAM project to enhance test reliability, maintainability, and resilience.

## Comprehensive Database Setup

### ResilientDatabaseSetup Module

The `XIAM.ResilientDatabaseSetup` module provides a comprehensive approach to database setup and initialization for tests:

```elixir
# In your test setup:
XIAM.ResilientDatabaseSetup.initialize_test_environment(tags)

# For individual database operations:
XIAM.ResilientDatabaseSetup.safely_run_db_operation(fn ->
  # Your database operation here
end)
```

This module provides:
- Reliable repository initialization with proper error handling
- Integrated ETS table setup for Phoenix and caching
- Proper sandbox configuration with ownership tracking
- Automatic recovery from transient database connection issues
- Detailed diagnostics when issues occur

### Database Connection Verification

To verify that a database connection is properly established:

```elixir
case XIAM.ResilientDatabaseSetup.verify_repository_connection(XIAM.Repo) do
  {:ok, _} -> :ok # Connection is good
  {:error, reason} -> 
    # Handle connection issue
    IO.warn("Database connection issue: #{inspect(reason)}")
end
```

## Resilient Test Patterns

### Safely Executing Database Operations

When testing database-dependent code, use the `XIAM.ResilientTestHelper.safely_execute_db_operation/2` function to handle potential transient failures:

```elixir
# Instead of:
{:ok, node} = Hierarchy.create_node(attrs)

# Use:
{:ok, node} = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
  Hierarchy.create_node(attrs)
end, max_attempts: 3)
```

This pattern:
- Automatically retries failed operations with configurable attempts
- Uses exponential backoff with jitter for optimal retry timing
- Ensures database connections are available before operations
- Provides detailed error reporting with attempt tracking
- Makes tests more resilient to transient database issues

### Safely Executing ETS Operations

For tests that interact with ETS tables, use the `XIAM.ResilientTestHelper.safely_execute_ets_operation/2` function:

```elixir
# Instead of:
result = :ets.lookup(MyTable, key)

# Use:
result = XIAM.ResilientTestHelper.safely_execute_ets_operation(fn ->
  :ets.lookup(MyTable, key)
end, fallback_value: [])
```

This pattern:
- Handles missing or not-yet-created ETS tables gracefully
- Provides a configurable fallback value
- Reduces test failures due to race conditions with ETS table initialization

## Proper Test Isolation

### Process Dictionary Isolation

When using the process dictionary in tests, make sure to properly isolate the data:

```elixir
# Example from HierarchyTestAdapter
defp get_test_accessible_nodes_from_dictionary(user_id) do
  # Handle both when Process.get() returns a map or a list
  dict_keys = case Process.get() do
    dict when is_map(dict) -> Map.keys(dict)
    dict when is_list(dict) -> Enum.map(dict, fn {key, _} -> key end)
    nil -> []
  end
  
  # Rest of the implementation...
end
```

### Enhanced Database Sandbox Setup

The DataCase module now uses ResilientDatabaseSetup for robust sandbox initialization:

```elixir
setup tags do
  # Use the comprehensive resilient database setup for better initialization
  # This handles ETS tables, database connections, and sandbox configuration
  XIAM.ResilientDatabaseSetup.initialize_test_environment(tags)
  :ok
end
```

This approach provides:
- Consistent database connection across test runs
- Proper sandbox process ownership tracking
- Better error handling for connection issues
- Integrated ETS table initialization

## Handling Access Control Tests

For tests involving access control and hierarchy relationships:

```elixir
# Example of granting access with resilient execution and proper ID type handling
XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
  # Convert IDs to integers explicitly to avoid type mismatches
  user_id = if is_binary(user.id), do: String.to_integer(user.id), else: user.id
  role_id = if is_binary(role.id), do: String.to_integer(role.id), else: role.id
  
  # Grant access with converted IDs
  Adapter.grant_access(user_id, node.id, role_id)
end, silent: true)

# When comparing IDs in test assertions, handle potential type mismatches
assert dept_role_id == role_id, 
       "Expected role ID #{role_id}, got #{dept_role_id} with type: #{inspect(dept_access.role_id)}"
```

## Handling Hierarchy Path Tests

The hierarchy system uses a path-based approach to manage relationships. To test this correctly:

```elixir
# Example of granting access with resilient execution and proper ID type handling
XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
  # Convert IDs to integers explicitly to avoid type mismatches
  user_id = if is_binary(user.id), do: String.to_integer(user.id), else: user.id
  role_id = if is_binary(role.id), do: String.to_integer(role.id), else: role.id
  
  # Grant access with converted IDs
  Adapter.grant_access(user_id, node.id, role_id)
end, silent: true)
```

## ETS Table Initialization

Phoenix creates ETS tables for endpoints, configuration, and live view components. To ensure these tables are available in tests, use the `XIAM.ETSTestHelper` module:

```elixir
# In test setup:
XIAM.ETSTestHelper.ensure_ets_tables_exist()

# For a specific table:
XIAM.ETSTestHelper.safely_ensure_table_exists(:my_table_name)
```

This approach is especially important for tests related to Phoenix endpoints, live views, and any code that uses ETS tables for caching.

## Hierarchy Cache Initialization

The hierarchy system uses several ETS tables for caching. Initialize them this way:

```elixir
# Initialize hierarchy cache tables with default counter values
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
```

## General Best Practices

1. **Generate unique data for each test**: Use functions like `System.unique_integer/1` to ensure test data doesn't conflict.

2. **Handle duplicate access grants**: The adapter will detect and handle duplicate access grants appropriately.

3. **Use markers in test dictionaries**: For special test cases, use markers in the process dictionary to differentiate between test contexts.

4. **Minimize test dependencies**: Avoid having tests depend on the state created by other tests.

5. **Proper cache invalidation**: Always ensure caches are properly invalidated before verifying test results:

```elixir
# Invalidate all caches before checking results
try do
  # Invalidate hierarchy cache completely
  XIAM.Cache.HierarchyCache.invalidate_all()
  
  # Also invalidate access caches at multiple levels
  XIAM.Hierarchy.AccessCache.invalidate_node(node_id)
  XIAM.Hierarchy.AccessCache.invalidate_user(user_id)
rescue
  # Gracefully handle any cache errors
  _ -> :ok
end
```

6. **Handle ETS table existence checks**: Always check if ETS tables exist before using them:

```elixir
# Create an ETS table for a test if it doesn't exist
XIAM.ETSTestHelper.safely_ensure_table_exists(:my_test_table)

# Insert a test entry with proper error handling
try do
  :ets.insert(:my_test_table, {key, value})
catch
  :error, _ -> :ok # Gracefully handle errors
end
```

7. **Run critical tests with `async: false`**: For tests with complex setup or that modify global state, avoid parallel execution by setting `async: false` in the test module attributes.

5. **Clean up after tests**: Use `on_exit/1` callbacks to ensure proper cleanup after tests.

## Troubleshooting Common Test Issues

### "Ecto repo was not started" Error

This usually indicates a sandbox setup issue. Make sure to:
- Use `XIAM.ResilientTestHelper.safely_execute_db_operation/2` for database operations
- Include proper setup with `XIAM.ETSTestHelper.ensure_ets_tables_exist()`

### ETS Lookup Errors

If you see errors about missing ETS tables:
- Use `XIAM.ETSTestHelper.ensure_ets_tables_exist()` in your setup
- Wrap ETS operations with `XIAM.ResilientTestHelper.safely_execute_ets_operation/2`

### Duplicate Access Grants

The `grant_access` function now properly handles duplicate access grants by returning an error tuple. Tests should expect this behavior.

### Uniqueness Constraint Errors

When dealing with uniqueness constraints (e.g., for node paths), implement retry logic to create resilient tests:

```elixir
defp create_node_with_retry(name, node_type, parent_id, retry_count \\ 0) do
  # Add retry suffix for subsequent attempts to ensure uniqueness
  actual_name = if retry_count > 0, do: "#{name}_retry#{retry_count}", else: name
  
  # Attempt to create the node
  case NodeManager.create_node(%{name: actual_name, node_type: node_type, parent_id: parent_id}) do
    {:ok, node} -> 
      # Success - return the node
      node
    {:error, %Ecto.Changeset{errors: errors}} ->
      # Check if this is a uniqueness constraint error
      path_error = Enum.find(errors, fn {field, {_msg, constraint_info}} -> 
        field == :path && Keyword.get(constraint_info, :constraint) == :unique 
      end)
      
      if path_error && retry_count < 5 do
        # Retry with a different name
        IO.puts("Retrying node creation with different name due to path collision")
        create_node_with_retry(name, node_type, parent_id, retry_count + 1)
      else
        # Either not a uniqueness error or we've exceeded retries
        raise "Failed to create node after #{retry_count} retries: #{inspect(errors)}"
      end
    {:error, error} ->
      # Handle other types of errors
      raise "Unexpected error creating node: #{inspect(error)}"
  end
end
```

### Phoenix LiveView Test Failures

If you encounter "unknown application: nil" errors in LiveView tests, ensure proper application configuration:

```elixir
# In your ETSTestHelper module or test setup:

# Set the application name for LiveView
Application.put_env(:phoenix_live_view, :app_name, :xiam)
Application.put_env(:phoenix, :json_library, Jason)

# Configure LiveView in the endpoint
basic_config = %{
  # Other config...
  live_view: [signing_salt: "test-lv-salt", application: :xiam],
  # Other config...
}
```

### ID Type Inconsistency

When IDs from different sources might be either strings or integers, convert them explicitly:

```elixir
# Convert ID to integer if it's a string
node_id = if is_binary(node.id), do: String.to_integer(node.id), else: node.id
```
