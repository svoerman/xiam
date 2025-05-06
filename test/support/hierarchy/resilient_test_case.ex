defmodule XIAM.ResilientTestCase do
  @moduledoc """
  A test case module that includes resilient testing utilities.
  
  This module extends ExUnit.CaseTemplate with resilient test patterns
  for dealing with ETS tables, database connections, and other
  transient issues that may occur in tests.
  """
  
  use ExUnit.CaseTemplate
  
  using do
    quote do
      use XIAM.DataCase, async: false
      import XIAM.ResilientTestHelper
      import XIAM.Hierarchy.AccessManagerTestHelper
      import XIAM.Hierarchy.AccessTestFixtures
      
      # Add common assertions
      def assert_error_response(result) do
        case result do
          {:error, _} -> assert true
          other -> flunk("Expected error, got: #{inspect(other)}")
        end
      end
      
      def assert_access_granted(check_result) do
        case check_result do
          true -> assert true
          {:ok, %{has_access: true}} -> assert true
          {:ok, %{has_access: has_access}} -> assert has_access
          %{has_access: true} -> assert true
          %{has_access: has_access} -> assert has_access
          other -> flunk("Expected access to be granted, but got: #{inspect(other)}")
        end
      end
      
      def assert_access_denied(check_result) do
        case check_result do
          false -> assert true
          {:ok, %{has_access: false}} -> assert true
          {:ok, %{has_access: has_access}} -> refute has_access
          %{has_access: false} -> assert true
          %{has_access: has_access} -> refute has_access
          other -> flunk("Expected access to be denied, but got: #{inspect(other)}")
        end
      end
      
      # Add helper for validating node responses
      def assert_valid_node_response(response, path_id) do
        nodes = normalize_node_response(response)
        refute Enum.empty?(nodes), "Expected non-empty nodes list but got: #{inspect(response)}"
        
        # Successfully found at least one node
        node_ids = extract_node_ids(nodes)
        assert Enum.member?(node_ids, path_id), 
               "Expected node ID #{path_id} in result, but got IDs: #{inspect(node_ids)}"
      end
    end
  end
  
  # Setup to run before every test to ensure consistent test environment
  setup do
    # Ensure ETS tables exist and are properly initialized
    XIAM.ETSTestHelper.ensure_ets_tables_exist()
    
    # Ensure the database repository is started
    XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
      # Make sure our cache is in a clean state for each test
      XIAM.Cache.HierarchyCache.invalidate_all()
    end)
    
    :ok
  end
end
