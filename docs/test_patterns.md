# Test Patterns in XIAM

This document outlines the testing patterns implemented in the XIAM project to enhance test reliability, maintainability, and resilience.

## Resilient Test Patterns

### Safely Executing Database Operations

When testing database-dependent code, use the `XIAM.ResilientTestHelper.safely_execute_db_operation/2` function to handle potential transient failures:

```elixir
# Instead of:
{:ok, node} = Hierarchy.create_node(attrs)

# Use:
{:ok, node} = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
  Hierarchy.create_node(attrs)
end, max_retries: 3)
```

This pattern:
- Automatically retries failed operations (configurable number of times)
- Adds a small delay between retries
- Provides better error reporting
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

### Database Sandbox Setup

The DataCase module provides a robust sandbox setup with mutex locking to avoid race conditions:

```elixir
# Setup with proper ETS table initialization
setup tags do
  # First ensure all required ETS tables exist
  XIAM.ETSTestHelper.ensure_ets_tables_exist()
  
  # Then set up the database sandbox
  XIAM.DataCase.setup_sandbox(tags)
  :ok
end
```

## Handling Access Control Tests

For tests involving access control and hierarchy relationships:

```elixir
# Example of granting access with resilient execution
XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
  Adapter.grant_access(user, node, role)
end, silent: true)
```

## General Best Practices

1. **Generate unique data for each test**: Use functions like `System.unique_integer/1` to ensure test data doesn't conflict.

2. **Handle duplicate access grants**: The adapter will detect and handle duplicate access grants appropriately.

3. **Use markers in test dictionaries**: For special test cases, use markers in the process dictionary to differentiate between test contexts.

4. **Minimize test dependencies**: Avoid having tests depend on the state created by other tests.

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
