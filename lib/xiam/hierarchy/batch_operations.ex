defmodule XIAM.Hierarchy.BatchOperations do
  @moduledoc """
  Module for performing batch operations on the hierarchy.
  
  This module provides functions to efficiently handle operations on multiple
  nodes simultaneously, optimizing performance for large hierarchies.
  """
  
  import Ecto.Query
  alias XIAM.Repo
  alias XIAM.Hierarchy.{Node, Access, AccessCache, NodeManager, AccessManager, PathCalculator}
  
  @doc """
  Grants access to multiple nodes for a user with specified role.
  
  ## Parameters
    * `user_id` - The ID of the user to grant access to
    * `node_ids` - List of node IDs to grant access to
    * `role_id` - The role ID to assign
    
  ## Returns
    * `{:ok, results}` - A list of result maps with node_id and status
  """
  def grant_batch_access(user_id, node_ids, role_id) do
    results = 
      Enum.map(node_ids, fn node_id ->
        case AccessManager.grant_access(user_id, node_id, role_id) do
          {:ok, access} -> 
            %{node_id: node_id, status: :success, access_id: access.id}
          {:error, reason} -> 
            %{node_id: node_id, status: :error, reason: reason}
        end
      end)
    
    {:ok, results}
  end
  
  @doc """
  Revokes user access from multiple nodes at once.
  
  ## Parameters
    * `user_id` - The ID of the user to revoke access from
    * `node_ids` - List of node IDs to revoke access from
    
  ## Returns
    * `{:ok, results}` - A list of result maps with node_id and status
  """
  def revoke_batch_access(user_id, node_ids) do
    results = 
      Enum.map(node_ids, fn node_id ->
        # First get the access record
        access = Repo.get_by(Access, user_id: user_id, node_id: node_id)
        
        if access do
          case AccessManager.revoke_access(access.id) do
            {:ok, _} -> 
              %{node_id: node_id, status: :success}
            {:error, reason} -> 
              %{node_id: node_id, status: :error, reason: reason}
          end
        else
          %{node_id: node_id, status: :error, reason: :access_not_found}
        end
      end)
    
    {:ok, results}
  end
  
  @doc """
  Deletes multiple nodes in a single transaction.
  
  ## Parameters
    * `node_ids` - List of node IDs to delete
    
  ## Returns
    * `{:ok, results}` - A list of result maps with node_id and status
  """
  def delete_batch_nodes(node_ids) do
    Repo.transaction(fn ->
      Enum.map(node_ids, fn node_id ->
        case NodeManager.get_node(node_id) do
          nil -> 
            %{node_id: node_id, status: :error, reason: :not_found}
          node ->
            # Get descendants before deletion for cache invalidation
            descendants = NodeManager.get_descendants(node_id)
            _descendant_ids = Enum.map(descendants, & &1.id)
            
            case NodeManager.delete_node(node) do
              {:ok, _} -> 
                # Cache invalidation is handled by NodeManager.delete_node
                %{node_id: node_id, status: :success, descendant_count: length(descendants)}
              {:error, reason} ->
                %{node_id: node_id, status: :error, reason: reason}
            end
        end
      end)
    end)
  end
  
  @doc """
  Moves multiple nodes to a new parent in a single transaction.
  
  ## Parameters
    * `node_ids` - List of node IDs to move
    * `new_parent_id` - ID of the new parent node
    
  ## Returns
    * `{:ok, results}` - A list of result maps with node_id and status
  """
  def move_batch_nodes(node_ids, new_parent_id) do
    # Verify the new parent exists
    new_parent = NodeManager.get_node(new_parent_id)
    
    if is_nil(new_parent) and new_parent_id != nil do
      {:error, :parent_not_found}
    else
      Repo.transaction(fn ->
        Enum.map(node_ids, fn node_id ->
          case NodeManager.get_node(node_id) do
            nil -> 
              %{node_id: node_id, status: :error, reason: :not_found}
            node ->
              # Skip if the node is already under this parent
              if node.parent_id == new_parent_id do
                %{node_id: node_id, status: :skipped, reason: :already_at_destination}
              else
                # Check for cycles - can't move a node to its own descendant
                if new_parent_id != nil && (node_id == new_parent_id || is_descendant?(new_parent_id, node_id)) do
                  %{node_id: node_id, status: :error, reason: :would_create_cycle}
                else
                  # Get descendants before move for cache invalidation
                  descendants = NodeManager.get_descendants(node_id)
                  descendant_ids = Enum.map(descendants, & &1.id)
                  
                  case NodeManager.move_node(node, new_parent_id) do
                    {:ok, moved_node} ->
                      # Invalidate cache for this node and all descendants
                      AccessCache.invalidate_node(node_id)
                      Enum.each(descendant_ids, &AccessCache.invalidate_node/1)
                      %{node_id: node_id, status: :success, new_path: moved_node.path}
                    {:error, reason} ->
                      %{node_id: node_id, status: :error, reason: reason}
                  end
                end
              end
          end
        end)
      end)
    end
  end
  
  defp is_descendant?(ancestor_id, node_id) do
    node = NodeManager.get_node(node_id)
    if is_nil(node) do
      false
    else
      PathCalculator.is_descendant?(node.path, ancestor_id)
    end
  end
  
  @doc """
  Efficiently checks access for a user to multiple nodes in one database query.
  
  ## Parameters
    * `user_id` - The ID of the user to check access for
    * `node_ids` - List of node IDs to check access to
    
  ## Returns
    * Map with node_ids as keys and boolean access status as values
  """
  def check_batch_access(user_id, node_ids) do
    if Enum.empty?(node_ids) do
      %{}
    else
      # Get all nodes first to get their paths
      nodes = from(n in Node, where: n.id in ^node_ids)
      |> Repo.all()
      |> Map.new(fn n -> {n.id, n.path} end)
      
      # Get all access grants for this user
      access_grants = AccessManager.list_user_access(user_id)
      access_paths = Enum.map(access_grants, fn access ->
        node = NodeManager.get_node(access.node_id)
        node && node.path
      end) |> Enum.reject(&is_nil/1)
      
      if Enum.empty?(access_paths) do
        # No access grants, so no access to any nodes
        Enum.map(node_ids, fn id -> {id, false} end) |> Map.new()
      else
        # For each node, check if any access path is an ancestor
        Enum.map(node_ids, fn id ->
          path = Map.get(nodes, id)
          
          if is_nil(path) do
            {id, false}
          else
            has_access = Enum.any?(access_paths, fn access_path ->
              PathCalculator.is_ancestor?(access_path, path) || path == access_path
            end)
            
            {id, has_access}
          end
        end)
        |> Map.new()
      end
    end
  end
end
