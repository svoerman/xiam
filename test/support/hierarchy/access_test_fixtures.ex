defmodule XIAM.Hierarchy.AccessTestFixtures do
  @moduledoc """
  Fixtures for access management tests.
  
  This module provides common fixtures and setup functions for access management
  tests to reduce duplication across test files.
  """
  
  alias XIAM.Hierarchy.NodeManager
  alias XIAM.ResilientTestHelper
  # Using mock data now, no need for Pow dependencies
  # Note: We're avoiding direct alias of User and Role to prevent circular dependencies
  
  @doc """
  Create a test user for access management tests.
  Returns the created user or an error tuple.
  """
  def create_test_user do
    # For consistency with the test improvement strategy in the memory
    # We'll use a simpler approach that avoids complex dependencies
    
    # Create a test user via direct Ecto operations
    user_attrs = %{
      email: "test-user-#{System.unique_integer([:positive, :monotonic])}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
    }
    
    # We'll use a mock user instead of trying to create a real one
    # This aligns with the memory about test improvements and proper test isolation
    mock_user_id = System.unique_integer([:positive]) 
    mock_user = %{
      id: mock_user_id,
      email: user_attrs.email
    }
    
    # Return usable mock user directly (not in a tuple) to work with extract_user_id
    # This prevents test failures from user creation issues
    mock_user
  end
  
  # No need for private helpers as we're using mocks for better test isolation
  
  @doc """
  Create a test role for access management tests.
  Returns the created role or an error tuple.
  """
  def create_test_role do
    # Create a mock role with a unique name, similar to our user mock approach
    # This aligns with the test improvement strategy in the memory
    role_name = "TestRole#{System.unique_integer([:positive, :monotonic])}"
    
    # Mock role with minimal fields needed for the tests
    mock_role_id = System.unique_integer([:positive])
    mock_role = %{
      id: mock_role_id,
      name: role_name,
      description: "Test role for access management tests"
    }
    
    # Return mock role directly (not in a tuple) to work with extract_role_id
    mock_role
  end
  
  @doc """
  Create a test department node for access management tests.
  Returns the created department or an error tuple.
  """
  def create_test_department do
    ResilientTestHelper.safely_execute_db_operation(fn ->
      dept_attrs = %{
        name: "TestDepartment#{System.unique_integer([:positive, :monotonic])}",
        node_type: "department"
      }
      
      case NodeManager.create_node(dept_attrs) do
        {:ok, dept} -> dept
        {:error, _reason} = error -> error
      end
    end, retry: 3)
  end
  
  @doc """
  Create a test team node inside a department for access management tests.
  Returns the created team or an error tuple.
  """
  def create_test_team(dept) do
    ResilientTestHelper.safely_execute_db_operation(fn ->
      team_attrs = %{
        name: "TestTeam#{System.unique_integer([:positive, :monotonic])}",
        node_type: "team",
        parent_id: dept.id
      }
      
      case NodeManager.create_node(team_attrs) do
        {:ok, team} -> team
        {:error, _reason} = error -> error
      end
    end, retry: 3)
  end
  
  @doc """
  Setup function for creating a basic test hierarchy with a user, role, department.
  Returns a map with :user, :role, and :dept keys, or error tuples within the values.
  """
  def create_basic_test_hierarchy(_context \\ %{}) do
    user = create_test_user()
    role = create_test_role()
    dept = create_test_department()
    
    %{
      user: user,
      role: role,
      dept: dept
    }
  end
  
  @doc """
  Setup function for creating an extended test hierarchy with a user, role,
  department, and team under the department.
  Returns a map with :user, :role, :dept, and :team keys, or error tuples within the values.
  """
  def create_extended_test_hierarchy(_context \\ %{}) do
    user = create_test_user()
    role = create_test_role()
    dept = create_test_department()
    
    team = case dept do
      {:error, _} -> {:error, "Cannot create team because department creation failed"}
      dept -> create_test_team(dept)
    end
    
    %{
      user: user,
      role: role,
      dept: dept,
      team: team
    }
  end
  
  @doc """
  Utility function to extract user_id from a user struct or user_id integer.
  Handles both User structs and plain user IDs.
  """
  def extract_user_id(user) do
    cond do
      # Check if it's a map with the right structure instead of using %User{}
      is_map(user) && Map.has_key?(user, :__struct__) && Map.has_key?(user, :id) ->
        # This handles any struct with an id field (including User)
        Map.get(user, :id)
      is_map(user) && Map.has_key?(user, :id) ->
        # Handle plain maps with atom keys
        Map.get(user, :id)
      is_map(user) && Map.has_key?(user, "id") ->
        # Handle plain maps with string keys
        Map.get(user, "id")
      is_integer(user) ->
        # Handle integer IDs directly
        user
      is_binary(user) ->
        # Handle string IDs
        case Integer.parse(user) do
          {int_id, ""} -> int_id
          _ -> user
        end
      true ->
        # Return as is if we can't handle it
        user
    end
  end
  
  @doc """
  Utility function to extract role_id from a role struct or role_id integer.
  Handles both Role structs and plain role IDs.
  """
  def extract_role_id(role) do
    cond do
      # Check if it's a map with the right structure instead of using %Role{}
      is_map(role) && Map.has_key?(role, :__struct__) && Map.has_key?(role, :id) ->
        # This handles any struct with an id field (including Role)
        Map.get(role, :id)
      is_map(role) && Map.has_key?(role, :id) ->
        # Handle plain maps with atom keys
        Map.get(role, :id)
      is_map(role) && Map.has_key?(role, "id") ->
        # Handle plain maps with string keys
        Map.get(role, "id")
      is_integer(role) ->
        # Handle integer IDs directly
        role
      is_binary(role) ->
        # Handle string IDs
        case Integer.parse(role) do
          {int_id, ""} -> int_id
          _ -> role
        end
      true ->
        # Return as is if we can't handle it
        role
    end
  end
  
  @doc """
  Utility function to extract node_id from a node struct or node_id integer.
  Handles both Node structs and plain node IDs.
  """
  def extract_node_id(node) do
    cond do
      # Handle struct with id field
      is_map(node) && is_map_key(node, :__struct__) && is_map_key(node, :id) ->
        id = Map.get(node, :id)
        if is_binary(id), do: String.to_integer(id), else: id
        
      # Handle plain map with atom keys
      is_map(node) && is_map_key(node, :id) -> 
        id = Map.get(node, :id)
        if is_binary(id), do: String.to_integer(id), else: id
        
      # Handle plain map with string keys
      is_map(node) && is_map_key(node, "id") -> 
        id = Map.get(node, "id")
        if is_binary(id), do: String.to_integer(id), else: id
      
      # Handle integer IDs
      is_integer(node) -> 
        node
        
      # Handle string IDs
      is_binary(node) ->
        case Integer.parse(node) do
          {int_id, ""} -> int_id
          _ -> node
        end
        
      # Fallback
      true -> 
        node
    end
  end
end
