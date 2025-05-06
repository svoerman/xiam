defmodule XIAM.HierarchyMockAdapter do
  @moduledoc """
  Provides mock implementations of Hierarchy functions for testing.

  This module simulates the behavior of the Hierarchy module without
  relying on the database, making it suitable for tests that need to
  verify access control behavior without creating actual database records.
  """

  # Use process dictionary as in-memory store for mock data
  # This approach is only intended for testing
  
  @doc """
  Mock implementation of grant_access that simulates the behavior
  without touching the database.
  """
  def grant_access(user_id, node_id, role_id) do
    user_id = XIAM.Hierarchy.IDHelper.normalize_user_id(user_id)
    node_id = XIAM.Hierarchy.IDHelper.normalize_node_id(node_id)
    role_id = XIAM.Hierarchy.IDHelper.normalize_role_id(role_id)
    
    # Get node path (stored during node creation)
    node_path = Process.get({:test_node_path, node_id})
    
    # Check if access already exists
    access_key = {user_id, node_path}
    existing_access = Process.get({:mock_access, access_key})
    
    if existing_access do
      # Update existing access
      updated_access = Map.put(existing_access, :role_id, role_id)
      Process.put({:mock_access, access_key}, updated_access)
      {:ok, updated_access}
    else
      # Create new access
      timestamp = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      mock_id = System.unique_integer([:positive, :monotonic])
      
      access = %{
        id: mock_id,
        user_id: user_id,
        role_id: role_id,
        access_path: node_path,
        inserted_at: timestamp,
        updated_at: timestamp
      }
      
      Process.put({:mock_access, access_key}, access)
      Process.put({:mock_access_by_id, mock_id}, access)
      
      # Maintain a list of access ids by user for revocation
      user_access_ids = Process.get({:user_access_ids, user_id}) || []
      Process.put({:user_access_ids, user_id}, [mock_id | user_access_ids])
      
      {:ok, access}
    end
  end
  
  @doc """
  Mock implementation of check_access that simulates the behavior
  without touching the database.
  """
  def check_access(user_id, node_id) do
    user_id = XIAM.Hierarchy.IDHelper.normalize_user_id(user_id)
    node_id = XIAM.Hierarchy.IDHelper.normalize_node_id(node_id)
    
    # Get node and its path
    node = Process.get({:test_node_data, node_id})
    node_path = node && node.path
    
    if !node_path do
      {false, nil, nil}
    else
      # Get all access grants for this user
      user_access_ids = Process.get({:user_access_ids, user_id}) || []
      access_grants = Enum.map(user_access_ids, fn id -> 
        Process.get({:mock_access_by_id, id})
      end) |> Enum.filter(&(&1 != nil))
      
      # Check if any access grant's path is an ancestor of this node's path
      # In a real implementation, this would use the ltree operator
      matching_access = Enum.find(access_grants, fn access ->
        String.starts_with?(node_path, access.access_path)
      end)
      
      if matching_access do
        role = %{id: matching_access.role_id, name: "Role #{matching_access.role_id}"}
        {true, node, role}
      else
        {false, node, nil}
      end
    end
  end
  
  @doc """
  Mock implementation of can_access? that wraps check_access.
  """
  def can_access?(user_id, node_id) do
    {has_access, _, _} = check_access(user_id, node_id)
    has_access
  end
  
  @doc """
  Mock implementation of revoke_access that simulates the behavior
  without touching the database.
  """
  def revoke_access(access_id) do
    access = Process.get({:mock_access_by_id, access_id})
    
    if access do
      # Clean up the process dictionary
      access_key = {access.user_id, access.access_path}
      Process.delete({:mock_access, access_key})
      Process.delete({:mock_access_by_id, access_id})
      
      # Update user's access list
      user_access_ids = Process.get({:user_access_ids, access.user_id}) || []
      updated_ids = Enum.filter(user_access_ids, fn id -> id != access_id end)
      Process.put({:user_access_ids, access.user_id}, updated_ids)
      
      {:ok, access}
    else
      {:error, :access_not_found}
    end
  end
  
  @doc """
  Mock implementation of revoke_user_access that revokes access for a user-node pair.
  """
  def revoke_user_access(user_id, node_id) do
    user_id = XIAM.Hierarchy.IDHelper.normalize_user_id(user_id)
    node_id = XIAM.Hierarchy.IDHelper.normalize_node_id(node_id)
    
    # Get node path
    node_path = Process.get({:test_node_path, node_id})
    
    if node_path do
      access_key = {user_id, node_path}
      access = Process.get({:mock_access, access_key})
      
      if access do
        revoke_access(access.id)
      else
        {:error, :access_not_found}
      end
    else
      {:error, :node_not_found}
    end
  end
  
  @doc """
  Creates a test node with the given attributes and sets up the necessary process dictionary entries.
  """
  def create_test_node(attrs) do
    id = attrs[:id] || System.unique_integer([:positive, :monotonic])
    path = attrs[:path] || "node_#{id}"
    
    node = Map.merge(%{
      id: id,
      path: path,
      name: attrs[:name] || "Test Node #{id}",
      node_type: attrs[:node_type] || "test",
      parent_id: attrs[:parent_id],
      inserted_at: NaiveDateTime.utc_now(),
      updated_at: NaiveDateTime.utc_now()
    }, attrs)
    
    # Store in process dictionary
    Process.put({:test_node_data, id}, node)
    Process.put({:test_node_path, id}, path)
    
    if node.parent_id do
      Process.put({:test_node_parent, id}, node.parent_id)
    end
    
    {:ok, node}
  end
  
  @doc """
  Mock implementation of move_node that prevents circular references.
  """
  def move_node(node_id, new_parent_id) do
    # Check for circular reference
    if would_create_cycle?(node_id, new_parent_id) do
      {:error, :circular_reference}
    else
      # Get the node to move
      node = Process.get({:test_node_data, node_id})
      
      # Get the new parent
      parent = Process.get({:test_node_data, new_parent_id})
      
      # Update the node's parent and path
      updated_node = %{node | 
        parent_id: new_parent_id,
        path: "#{parent.path}.#{node.name}",
        updated_at: NaiveDateTime.utc_now()
      }
      
      # Update the process dictionary
      Process.put({:test_node_data, node_id}, updated_node)
      Process.put({:test_node_path, node_id}, updated_node.path)
      Process.put({:test_node_parent, node_id}, new_parent_id)
      
      # Update the paths of all descendant nodes (recursive operation)
      update_descendant_paths(node_id)
      
      {:ok, updated_node}
    end
  end
  
  # Helper function to check if moving a node would create a cycle
  defp would_create_cycle?(node_id, new_parent_id) do
    # Moving to self would create a cycle
    if node_id == new_parent_id do
      true
    else
      # Check if the new parent is a descendant of the node being moved
      current_parent_id = new_parent_id
      
      # Traverse up the tree until we reach the root or find a cycle
      path_to_root(current_parent_id, node_id)
    end
  end
  
  # Recursively check if target_id is in the path to root from start_id
  defp path_to_root(start_id, target_id) do
    cond do
      # If no parent, we've reached the root without finding a cycle
      start_id == nil -> false
      
      # If the parent is the target, we found a cycle
      start_id == target_id -> true
      
      # Otherwise, continue traversing up
      true -> 
        parent_id = Process.get({:test_node_parent, start_id})
        path_to_root(parent_id, target_id)
    end
  end
  
  # Update the paths of all descendants of a node
  defp update_descendant_paths(node_id) do
    # Find all nodes that have this node as parent
    node = Process.get({:test_node_data, node_id})
    
    # Find all child nodes more safely
    # Get all keys in the process dictionary that match our pattern
    child_nodes = for {{:test_node_parent, child_id}, parent_id} <- Process.get(),
                      parent_id == node_id,
                      child_id != node_id do
      child_id
    end
    
    # Update each child recursively
    Enum.each(child_nodes, fn child_id ->
      child = Process.get({:test_node_data, child_id})
      updated_child = %{child | 
        path: "#{node.path}.#{child.name}",
        updated_at: NaiveDateTime.utc_now()
      }
      
      Process.put({:test_node_data, child_id}, updated_child)
      Process.put({:test_node_path, child_id}, updated_child.path)
      
      # Recursively update this child's descendants
      update_descendant_paths(child_id)
    end)
  end
end
