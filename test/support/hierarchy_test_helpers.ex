defmodule XIAM.HierarchyTestHelpers do
  @moduledoc """
  Helper functions for testing the Hierarchy module.
  
  This module provides abstraction over the actual implementation details,
  allowing tests to be resilient to changes in the underlying implementation.
  """
  
  import ExUnit.Assertions
  alias XIAM.Hierarchy
  
  @doc """
  Creates a standard test user.
  
  Returns the created user struct.
  """
  def create_test_user(attrs \\ %{}) do
    # Use the proper user creation function from test_helpers.ex
    # This ensures we create a real database record that won't violate foreign key constraints
    {:ok, user} = XIAM.TestHelpers.create_test_user(attrs)
    user
  end
  
  @doc """
  Creates a test role.
  
  Returns the created role struct.
  """
  def create_test_role(name, attrs \\ %{}) do
    # Use the XIAM.TestHelpers implementation which creates database records
    case XIAM.TestHelpers.create_test_role(name, attrs) do
      {:ok, role} -> role
      {:error, changeset} -> raise "Failed to create test role: #{inspect(changeset)}"
    end
  end
  
  @doc """
  Creates a hierarchy tree with the following structure:
  
  Root (organization)
  └── Department (department)
      └── Team (team)
          └── Project (project)
  
  Returns a map with the created nodes.
  """
  def create_hierarchy_tree do
    # Use timestamp + unique integer to avoid path collisions
    timestamp = System.system_time(:millisecond)
    unique_id = "#{timestamp}_#{System.unique_integer([:positive, :monotonic])}"
    
    # Use resilient operations with retry logic wrapped by ResilientTestHelper
    XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
      # Create the root node with resilient creation pattern
      root = create_node_with_retry("Root_#{unique_id}", "organization", nil)
      
      # Create department under root
      dept = create_node_with_retry("Department_#{unique_id}", "department", root.id)
      
      # Create team under department
      team = create_node_with_retry("Team_#{unique_id}", "team", dept.id)
      
      # Create project under team
      project = create_node_with_retry("Project_#{unique_id}", "project", team.id)
      
      # Return the hierarchy map
      %{root: root, dept: dept, team: team, project: project}
    end)
  end
  
  @doc """
  Creates a node with retry logic to handle uniqueness constraint errors.
  This function implements the resilient pattern for node creation in tests.
  
  ## Parameters
  - name: The name for the node
  - node_type: The type of node (organization, department, team, etc.)
  - parent_id: The ID of the parent node, or nil for root nodes
  - retry_count: Counter for retries, defaults to 0 (internal use)
  
  ## Returns
  The created node on success, raises an exception after 5 failed retries.
  """
  def create_node_with_retry(name, node_type, parent_id, retry_count \\ 0) do
    # Add retry suffix for subsequent attempts to ensure uniqueness
    actual_name = if retry_count > 0, do: "#{name}_retry#{retry_count}", else: name
    
    # Prepare node attributes
    attrs = %{name: actual_name, node_type: node_type, parent_id: parent_id}
    
    # Attempt to create the node
    case Hierarchy.create_node(attrs) do
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
          IO.puts("Retrying node creation with different name due to path collision: #{actual_name}")
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
  
  @doc """
  Creates a child node under the specified parent.
  
  Abstracts away the implementation details of how child nodes
  are created in the actual system.
  
  Args:
    - parent: The parent node struct
    - attrs: Attributes for the child node
  
  Returns:
    - {:ok, node} on success
    - {:error, changeset} on failure
  """
  def create_child_node(parent, attrs) do
    # Use create_node with parent_id since create_child_node doesn't exist
    Hierarchy.create_node(Map.put(attrs, :parent_id, parent.id))
  end
  
  @doc """
  Verifies that a node has the expected structure for API responses.
  
  This ensures that no raw Ecto associations are included in the response,
  which could cause JSON encoding errors.
  
  Raises assertions if the structure is invalid.
  """
  def verify_node_structure(node) do
    # Check required fields
    assert is_map(node), "Node should be a map"
    assert Map.has_key?(node, :id), "Node should have an :id field"
    # In the current implementation, IDs can be integers
    assert is_binary(node.id) or is_integer(node.id), "Node ID should be a string or integer"
    assert Map.has_key?(node, :path), "Node should have a :path field"
    assert is_binary(node.path), "Node path should be a string"
    assert Map.has_key?(node, :name), "Node should have a :name field"
    assert is_binary(node.name), "Node name should be a string"
    assert Map.has_key?(node, :node_type), "Node should have a :node_type field"
    assert is_binary(node.node_type), "Node type should be a string"
    
    # Verify no raw Ecto associations
    refute Map.has_key?(node, :__struct__), "Node should not have :__struct__ (Ecto struct)"
    refute Map.has_key?(node, :__meta__), "Node should not have :__meta__ (Ecto metadata)"
    refute Map.has_key?(node, :parent), "Node should not have raw :parent association"
    refute Map.has_key?(node, :children), "Node should not have raw :children association"
    
    # Return the node for chaining
    node
  end
  
  @doc """
  Verifies that an access grant has the expected structure for API responses.
  
  Raises assertions if the structure is invalid.
  """
  def verify_access_grant_structure(grant) do
    # Check required fields
    assert is_map(grant), "Access grant should be a map"
    assert Map.has_key?(grant, :user_id), "Access grant should have a :user_id field"
    assert Map.has_key?(grant, :role_id), "Access grant should have a :role_id field"
    assert Map.has_key?(grant, :access_path), "Access grant should have an :access_path field"
    
    # Verify backward compatibility fields
    assert Map.has_key?(grant, :path_id), "Access grant should have a derived :path_id field"
    assert grant.path_id == Path.basename(grant.access_path), "path_id should be the basename of access_path"
    
    # Verify no raw Ecto associations
    refute Map.has_key?(grant, :__struct__), "Grant should not have :__struct__ (Ecto struct)"
    refute Map.has_key?(grant, :user), "Grant should not have raw :user association"
    refute Map.has_key?(grant, :role), "Grant should not have raw :role association"
    
    # Return the grant for chaining
    grant
  end
  
  @doc """
  Asserts that a path has a valid structure.
  
  Args:
    - path: The path to validate
    
  Raises assertion errors if the path is invalid.
  """
  def assert_valid_path(path) do
    assert is_binary(path), "Path should be a string"
    # In the current implementation, paths use dots instead of slashes and don't start with '/'
    refute String.contains?(path, ".."), "Path should not contain consecutive dots"
    refute String.ends_with?(path, "."), "Path should not end with a dot"
    
    # Return the path for chaining
    path
  end
  
  @doc """
  Grants access to a node for a user with the specified role.
  
  Args:
    - user: The user to grant access to
    - node: The node to grant access to
    - role: The role to grant
    
  Returns:
    - {:ok, access_grant} on success
    - {:error, reason} on failure
  """
  def grant_node_access(user, node, role) do
    Hierarchy.grant_access(user.id, node.id, role.id)
  end
  
  @doc """
  Verifies that a response from access check operations has the expected structure.
  
  Args:
    - result: The result from an access check operation
    
  Raises assertions if the structure is invalid.
  """
  def verify_access_check_result(result) do
    # Check basic structure
    assert is_map(result), "Access check result should be a map"
    assert Map.has_key?(result, :has_access), "Result should have a :has_access field"
    assert is_boolean(result.has_access), "has_access should be a boolean"
    
    # If access is granted, verify node and role structure
    if result.has_access do
      assert Map.has_key?(result, :node), "Result should have a :node field when access is granted"
      verify_node_structure(result.node)
      
      assert Map.has_key?(result, :role), "Result should have a :role field when access is granted"
      assert Map.has_key?(result.role, :id), "Role should have an :id field"
      assert Map.has_key?(result.role, :name), "Role should have a :name field"
    end
    
    # Return the result for chaining
    result
  end
end
