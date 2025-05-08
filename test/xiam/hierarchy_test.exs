defmodule XIAM.HierarchyTest do
  @moduledoc """
  XIAM Hierarchy Test Organization
  
  NOTE: This test file has been refactored into specialized test files
  for better organization and maintenance. The tests have been migrated
  to the following specialized files:
  
  - test/xiam/hierarchy/node_management_test.exs
    - Node CRUD operations (create, read, update, delete)
    
  - test/xiam/hierarchy/path_calculator_test.exs
    - Path generation, validation, and manipulation tests
    
  - test/xiam/hierarchy/tree_operation_test.exs
    - Tree structure operations (is_descendant?, move_subtree)
    
  - test/xiam/hierarchy/access_manager_test.exs
    - Access control operations (grant_access, revoke_access, can_access?)
    
  - test/xiam/hierarchy/integration_test.exs
    - Cross-module interaction tests
    
  If you need to add new tests, please add them to the appropriate
  specialized test file rather than this file.
  """
  
  use ExUnit.Case

  test "hierarchy tests are now in specialized files" do
    # This simple test verifies that the file loads correctly
    # and serves as a reminder that tests have been moved to specialized files
    assert true, "This file exists only as an index to the specialized test files"
  end
end
