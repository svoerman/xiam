defmodule XIAM.Hierarchy do
  @moduledoc """
  The Hierarchy context provides functions for managing hierarchical entities and access control.
  This module serves as a facade for the specialized sub-modules that handle specific aspects
  of the hierarchy system.
  """

  alias XIAM.Hierarchy.NodeManager
  alias XIAM.Hierarchy.AccessManager
  alias XIAM.Hierarchy.PathCalculator
  alias XIAM.Hierarchy.IDHelper

  # Node Management delegations

  @doc """
  Creates a new node. If parent_id is provided, it will be created as a child of that node.
  If no parent_id is provided, it will be created as a root node.
  """
  defdelegate create_node(attrs), to: NodeManager

  @doc """
  Gets a node by ID with caching for improved performance.
  """
  defdelegate get_node(id), to: NodeManager

  @doc """
  Gets a node by ID without using the cache.
  """
  defdelegate get_node_raw(id), to: NodeManager

  @doc """
  Gets a node by its path with caching for improved performance.
  """
  defdelegate get_node_by_path(path), to: NodeManager

  @doc """
  Lists all nodes, ordered by path.
  """
  defdelegate list_nodes, to: NodeManager

  @doc """
  Lists only root nodes (nodes without parents).
  """
  defdelegate list_root_nodes, to: NodeManager

  @doc """
  Paginates nodes for more efficient loading of large hierarchies.
  """
  defdelegate paginate_nodes(page \\ 1, per_page \\ 50), to: NodeManager

  @doc """
  Search for nodes by name or path, limit results to improve performance.
  """
  defdelegate search_nodes(term, limit \\ 100), to: NodeManager

  @doc """
  Gets direct children of a node with caching for improved performance.
  """
  defdelegate get_direct_children(parent_id), to: NodeManager

  @doc """
  Gets all descendants of a node (children, grandchildren, etc).
  """
  defdelegate get_descendants(parent_id), to: NodeManager

  @doc """
  Updates a node's attributes.
  """
  defdelegate update_node(node, attrs), to: NodeManager

  @doc """
  Deletes a node and all its descendants.
  """
  defdelegate delete_node(node), to: NodeManager

  @doc """
  Moves a node and all its descendants to a new parent.
  """
  defdelegate move_node(node, new_parent_id), to: NodeManager

  @doc """
  Batch creates nodes with parent-child relationships.
  """
  defdelegate batch_create_nodes(nodes_params), to: NodeManager

  @doc """
  Invalidate cache entries related to a node and its relationships.
  """
  defdelegate invalidate_node_caches(node), to: NodeManager

  # Access Management delegations

  @doc """
  Grants access to a user for a specific node with a specified role.
  """
  defdelegate grant_access(user_id, node_id, role_id), to: AccessManager

  @doc """
  Revokes access for a user to a specific node.
  """
  defdelegate revoke_access(access_id), to: AccessManager

  @doc """
  Lists all access grants for a specific node.
  """
  defdelegate list_node_access(node_id), to: AccessManager

  @doc """
  Lists all access grants for a user across all nodes.
  """
  defdelegate list_user_access(user_id), to: AccessManager

  @doc """
  Lists all accessible nodes for a user.
  """
  defdelegate list_accessible_nodes(user_id), to: AccessManager

  @doc """
  Checks if a user has access to a specific node.
  """
  defdelegate check_access(user_id, node_id), to: AccessManager

  @doc """
  Checks if a user has access to a node at a specific path.
  """
  defdelegate check_access_by_path(user_id, path), to: AccessManager

  @doc """
  Bulk grants access to multiple users for multiple nodes.
  """
  defdelegate batch_grant_access(access_list), to: AccessManager

  @doc """
  Bulk revokes access for multiple access grants.
  """
  defdelegate batch_revoke_access(access_ids), to: AccessManager

  @doc """
  Invalidates all access caches for a user.
  """
  defdelegate invalidate_user_access_cache(user_id), to: AccessManager

  @doc """
  Invalidates all access caches for a node.
  """
  defdelegate invalidate_node_access_cache(node_id), to: AccessManager

  # Path Calculator delegations
  
  @doc """
  Builds a child path by appending a sanitized name to the parent path.
  """
  defdelegate build_child_path(parent_path, name), to: PathCalculator

  @doc """
  Sanitizes a name for use in a path.
  """
  defdelegate sanitize_name(name), to: PathCalculator

  @doc """
  Gets the parent path from a given path by removing the last label.
  """
  defdelegate parent_path(path), to: PathCalculator

  @doc """
  Gets the last label from a path (the node's own name part).
  """
  defdelegate path_label(path), to: PathCalculator
  
  # Functions added for backward compatibility with tests
  
  @doc """
  Checks if a node is a descendant of another node.
  Used by tests.
  """
  def is_descendant?(descendant_id, ancestor_id) do
    descendant = NodeManager.get_node(descendant_id)
    ancestor = NodeManager.get_node(ancestor_id)
    
    if is_nil(descendant) || is_nil(ancestor) do
      false
    else
      PathCalculator.is_ancestor?(ancestor.path, descendant.path)
    end
  end
  
  @doc """
  Moves a node and its descendants to a new parent.
  Renamed to move_node in the NodeManager but keeping for backward compatibility.
  """
  def move_subtree(node, new_parent_id) do
    NodeManager.move_node(node, new_parent_id)
  end
  
  @doc """
  Checks if a user has access to a node.
  Returns true if user has access, false otherwise.
  """
  def can_access?(user_id, node_id) do
    # Normalize IDs to ensure consistent types
    user_id = IDHelper.normalize_user_id(user_id)
    node_id = IDHelper.normalize_node_id(node_id)
    
    # The AccessManager.check_access now returns a tuple with a map for consistency with tests
    # Extract just the boolean value for backward compatibility
    case AccessManager.check_access(user_id, node_id) do
      {:ok, %{has_access: has_access}} -> has_access
      {has_access, _, _} -> has_access
      error -> 
        # For any error response, assume no access
        false
    end
  end
  
  @doc """
  Revokes user access from a node.
  Used by tests with a different parameter pattern than the AccessManager version.
  """
  def revoke_access(user_id, node_id) do
    # Normalize IDs to ensure consistent types
    user_id = IDHelper.normalize_user_id(user_id)
    node_id = IDHelper.normalize_node_id(node_id)
    
    # First find the node to get its path
    case NodeManager.get_node(node_id) do
      nil -> 
        {:error, :node_not_found}
      
      node ->
        # Then find the access record using user_id and the node's path
        access = XIAM.Repo.get_by(XIAM.Hierarchy.Access, user_id: user_id, access_path: node.path)
        
        if access do
          AccessManager.revoke_access(access.id)
        else
          {:error, :access_not_found}
        end
    end
  end
end
