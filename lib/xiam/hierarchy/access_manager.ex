defmodule XIAM.Hierarchy.AccessManager do
  @moduledoc """
  Manages access control for hierarchy nodes.
  Extracted from the original XIAM.Hierarchy module to improve maintainability.
  """

  import Ecto.Query
  alias XIAM.Repo
  alias XIAM.Hierarchy.{Access, Node}
  alias XIAM.Hierarchy.NodeManager
  alias XIAM.Cache.HierarchyCache
  alias XIAM.Hierarchy.AccessCache

  @doc """
  Grants access to a user for a specific node with a specified role.
  """
  def grant_access(user_id, node_id, role_id) do
    # Check if node exists
    case NodeManager.get_node(node_id) do
      nil ->
        {:error, :node_not_found}

      node ->
        # Get access_path from node
        access_path = node.path
        
        # Check if access already exists
        case Repo.get_by(Access, user_id: user_id, access_path: access_path) do
          nil ->
            # Create new access
            %Access{}
            |> Access.changeset(%{user_id: user_id, access_path: access_path, role_id: role_id})
            |> Repo.insert()
            |> tap(fn 
              {:ok, _access} -> 
                # Invalidate cache
                AccessCache.invalidate_user(user_id)
                AccessCache.invalidate_node(node_id)
              _ -> :ok
            end)

          existing_access ->
            # Update existing access
            existing_access
            |> Access.changeset(%{role_id: role_id})
            |> Repo.update()
            |> tap(fn 
              {:ok, _access} -> 
                # Invalidate cache
                AccessCache.invalidate_user(user_id)
                AccessCache.invalidate_node(node_id)
              _ -> :ok
            end)
        end
    end
  end

  @doc """
  Revokes access for a user to a specific node.
  """
  def revoke_access(access_id) do
    case Repo.get(Access, access_id) do
      nil ->
        {:error, :access_not_found}

      access ->
        result = Repo.delete(access)
        
        # Invalidate cache on successful deletion
        case result do
          {:ok, deleted_access} ->
            AccessCache.invalidate_user(deleted_access.user_id)
            # Since we don't have node_id directly in the access record,
            # we need to invalidate through the access_path
            # We invalidate the cache by just calling invalidate_user
            # as the node id would require extra lookup
          _ -> :ok
        end
        
        result
    end
  end

  @doc """
  Lists all access grants for a specific node.
  """
  def list_node_access(node_id) do
    # First get the node's path
    case NodeManager.get_node(node_id) do
      nil -> []
      node ->
        Access
        |> where([a], a.access_path == ^node.path)
        |> Repo.all()
        |> Repo.preload([:role])
    end
  end

  @doc """
  Lists all access grants for a user across all nodes.
  """
  def list_user_access(user_id) do
    Access
    |> where([a], a.user_id == ^user_id)
    |> Repo.all()
    |> Repo.preload([:role])
  end

  @doc """
  Lists all accessible nodes for a user.
  This takes into account hierarchical access - if a user has access to a parent node,
  they also have access to all child nodes.
  """
  def list_accessible_nodes(user_id) do
    # Ensure user_id is an integer for Ecto queries
    user_id = if is_binary(user_id), do: String.to_integer(user_id), else: user_id
    
    # Function to fetch accessible nodes directly from the database
    fetch_accessible_nodes = fn ->
      # First get all access records for the user
      access_paths =
        from(a in Access,
          where: a.user_id == ^user_id,
          select: {a.access_path, a.role_id}
        )
        |> Repo.all()

      # Then find all nodes that are under these paths
      access_paths
      |> Enum.reduce([], fn {path, role_id}, acc ->
        # Find all nodes under this path
        # Using fragment with ltree operator was causing encoding issues
        # Instead, we'll use a raw SQL query with proper parameter binding
        sql = "SELECT n.id, $1, n.path, n.node_type, n.name, n.metadata, n.parent_id, n.inserted_at, n.updated_at "
             <> "FROM hierarchy_nodes n "
             <> "WHERE n.path::ltree <@ $2::ltree"
        
        # Parameters need to be explicitly cast to the correct types for PostgreSQL
        # Convert integers to strings to avoid encoding errors
        role_id_param = if is_integer(role_id), do: to_string(role_id), else: role_id
        params = [role_id_param, path]
        
        # Execute the query and convert the results to the expected format
        nodes = 
          Repo.query!(sql, params)
          |> Map.get(:rows)
          |> Enum.map(fn [id, role_id, path, node_type, name, metadata, parent_id, inserted_at, updated_at] ->
            node = %Node{
              id: id,
              path: path,
              node_type: node_type,
              name: name,
              metadata: metadata,
              parent_id: parent_id,
              inserted_at: inserted_at,
              updated_at: updated_at
            }
            {id, role_id, node}
          end)

        acc ++ nodes
      end)
      |> Enum.uniq_by(fn {id, _, _} -> id end)
      |> Enum.map(fn {_id, role_id, node} -> 
        # Return the node with the role_id added to it rather than nesting the node
        # This matches what the tests expect
        Map.put(node, :role_id, role_id)
      end)
    end

    cache_key = "user_accessible_nodes:#{user_id}"

    HierarchyCache.get_or_store(cache_key, fetch_accessible_nodes, 300_000) # 5 minute TTL
  end

  @doc """
  Checks if a user has access to a specific node.
  Returns {true, node, role} if user has access, {false, nil, nil} otherwise.
  """
  def check_access(user_id, node_id) do
    case NodeManager.get_node(node_id) do
      nil ->
        {false, nil, nil}

      node ->
        check_access_by_path(user_id, node.path)
    end
  end

  @doc """
  Checks if a user has access to a node at a specific path.
  Returns {true, node, role} if user has access, {false, nil, nil} otherwise.
  """
  def check_access_by_path(user_id, path) do
    # Function to check access directly from the database
    check_access_db = fn ->
      # First get the node by path
      node = NodeManager.get_node_by_path(path)

      case node do
        nil ->
          {false, nil, nil}

        node ->
          # Get all access records for this user
          access_paths =
            from(a in Access,
              where: a.user_id == ^user_id,
              select: {a.access_path, a.role_id, a.id}
            )
            |> Repo.all()

          # Check if any of the access paths are ancestors of this node
          access_match =
            Enum.find(access_paths, fn {access_path, _, _} ->
              # We need to use $1, $2 placeholders for PostgreSQL raw queries, not ?
              fragment_sql = "$1::ltree <@ $2::ltree"
              params = [path, access_path]

              Repo.query!("SELECT #{fragment_sql}", params).rows
              |> List.first()
              |> List.first()
            end)

          case access_match do
            nil ->
              {false, node, nil}

            {_path, role_id, _access_id} ->
              role = Xiam.Rbac.get_role(role_id)
              {true, node, role}
          end
      end
    end

    cache_key = "access_check:#{user_id}:#{path}"

    AccessCache.get_or_store(cache_key, check_access_db, 300_000) # 5 minute TTL
  end

  @doc """
  Bulk grants access to multiple users for multiple nodes.
  """
  def batch_grant_access(access_list) do
    Repo.transaction(fn ->
      Enum.map(access_list, fn %{user_id: user_id, node_id: node_id, role_id: role_id} ->
        case grant_access(user_id, node_id, role_id) do
          {:ok, access} -> access
          {:error, reason} -> Repo.rollback({:error, reason})
        end
      end)
    end)
  end

  @doc """
  Bulk revokes access for multiple access grants.
  """
  def batch_revoke_access(access_ids) do
    Repo.transaction(fn ->
      Enum.map(access_ids, fn access_id ->
        case revoke_access(access_id) do
          {:ok, access} -> access
          {:error, reason} -> Repo.rollback({:error, reason})
        end
      end)
    end)
  end

  @doc """
  Invalidates all access caches for a user.
  """
  def invalidate_user_access_cache(user_id) do
    AccessCache.invalidate_user(user_id)
    HierarchyCache.invalidate("user_accessible_nodes:#{user_id}")
  end

  @doc """
  Invalidates all access caches for a node.
  """
  def invalidate_node_access_cache(node_id) do
    AccessCache.invalidate_node(node_id)
    
    # Also need to invalidate user caches, but we don't know which users
    # So we'd need a separate task to invalidate all user caches
    :ok
  end
end
