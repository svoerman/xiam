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
  alias XIAM.Hierarchy.Node

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
  defdelegate batch_create_nodes(nodes_params), to: XIAM.Hierarchy.BatchCreateNodesFix

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
  Checks if a user has access to a specific node, returning only boolean.
  This function handles multiple formats for backward compatibility.
  """
  def can_access?(user_id, node_id) do
    # Normalize IDs to ensure consistent types
    user_id = IDHelper.normalize_user_id(user_id)
    node_id = IDHelper.normalize_node_id(node_id)
    
    # Handle multiple response formats for resilience
    case AccessManager.check_access(user_id, node_id) do
      {:ok, %{has_access: access}} when is_boolean(access) -> access
      {:ok, _} -> false
      {:error, _} -> false
      {has_access, _, _} when is_boolean(has_access) -> has_access
      other when is_boolean(other) -> other
      _ -> false
    end
  end

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
  Calculates the path for a node based on its parent's path.
  """
  def calculate_path(node) do
    if node.parent_id do
      case get_node(node.parent_id) do
        {:ok, parent} -> "#{parent.path}.#{node.id}"
        _ -> "#{node.id}"
      end
    else
      "#{node.id}"
    end
  end

  @doc """
  Validates if a path is properly formatted.
  """
  def valid_path?(nil), do: false
  def valid_path?(""), do: false
  def valid_path?(path) when is_binary(path) do
    # Paths should not start or end with . and should not have empty parts or invalid chars
    not String.starts_with?(path, ".") and
    not String.ends_with?(path, ".") and
    not String.contains?(path, "..") and
    not String.contains?(path, "/") and # Explicitly disallow '/'
    String.match?(path, ~r/^[^.]+(\.[^.]+)*$/)
  end

  @doc """
  Splits a path into its component node IDs.
  """
  def get_path_parts(nil), do: []
  def get_path_parts(""), do: []
  def get_path_parts(path) when is_binary(path) do
    String.split(path, ".")
  end

  @doc """
  Gets the parent path from a node path.
  """
  def get_parent_path(nil), do: nil
  def get_parent_path(""), do: nil
  def get_parent_path(path) when is_binary(path) do
    parts = get_path_parts(path)
    case length(parts) do
      1 -> nil  # Root node has no parent
      _ ->
        parts
        |> Enum.take(length(parts) - 1)
        |> Enum.join(".")
    end
  end

  @doc """
  Gets the deepest node ID from a path.
  """
  def get_deepest_node_id(nil), do: nil
  def get_deepest_node_id(""), do: nil
  def get_deepest_node_id(path) when is_binary(path) do
    String.split(path, ".") |> List.last()
  end

  @doc """
  Checks if a path contains another path (ancestor relationship).
  """
  def path_contains?(nil, _), do: false
  def path_contains?(_, nil), do: false
  def path_contains?(path, sub_path) when is_binary(path) and is_binary(sub_path) do
    path_parts = get_path_parts(path)
    sub_path_parts = get_path_parts(sub_path)
    
    # Ensure sub_path_parts is not empty before checking
    if sub_path_parts == [] do
      false
    else
      length(sub_path_parts) <= length(path_parts) and
      Enum.take(path_parts, length(sub_path_parts)) == sub_path_parts
    end
  end

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
  
  This function can accept either a Node struct or a node ID as the first argument.
  """
  def move_subtree(%Node{} = node, new_parent_id) do
    NodeManager.move_node(node.id, new_parent_id)
  end
  
  def move_subtree(node_id, new_parent_id) when is_integer(node_id) or is_binary(node_id) do
    case NodeManager.get_node(node_id) do
      nil -> {:error, :node_not_found}
      node -> NodeManager.move_node(node.id, new_parent_id)
    end
  end
  
  # Second implementation merged with the one above
  
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
