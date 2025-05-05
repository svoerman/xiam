defmodule XIAMWeb.API.HierarchyController do
  use XIAMWeb, :controller
  import Ecto.Query
  
  alias XIAM.Hierarchy
  alias XIAM.Hierarchy.{BatchOperations, AccessCache}
  alias XIAM.Repo
  
  action_fallback XIAMWeb.FallbackController
  
  # Functions for new API routes
  
  @doc """
  GET /api/hierarchy/nodes
  Lists all hierarchy nodes.
  """
  def list_nodes(conn, params) do
    # If root_only param is present, use the optimized root nodes function
    nodes = if Map.get(params, "root_only") == "true" do
      Hierarchy.list_root_nodes()
    else
      Hierarchy.list_nodes()
    end
    render(conn, :index, nodes: nodes)
  end

  @doc """
  GET /api/hierarchy/nodes/roots
  Lists only root hierarchy nodes (optimized endpoint).
  """
  def list_root_nodes(conn, _params) do
    nodes = Hierarchy.list_root_nodes()
    render(conn, :index, nodes: nodes)
  end

  @doc """
  POST /api/hierarchy/nodes
  Creates a new hierarchy node.
  """
  def create_node(conn, node_params) do
    case Hierarchy.create_node(node_params) do
      {:ok, node} ->
        conn
        |> put_status(:created)
        |> render(:show, node: node, children: [])
      
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(XIAMWeb.ErrorJSON)
        |> render("error.json", changeset: changeset)
      
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  @doc """
  GET /api/hierarchy/nodes/:id
  Gets a specific hierarchy node.
  """
  def get_node(conn, %{"id" => id}) do
    case Hierarchy.get_node(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Node not found"})
      
      node ->
        render(conn, :show, node: node, children: [])
    end
  end

  @doc """
  PUT /api/hierarchy/nodes/:id
  Updates a hierarchy node.
  """
  def update_node(conn, %{"id" => id} = params) do
    case Hierarchy.get_node(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Node not found"})
      
      node ->
        case Hierarchy.update_node(node, params) do
          {:ok, updated_node} ->
            render(conn, :show, node: updated_node, children: [])
          
          {:error, %Ecto.Changeset{} = changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> put_view(XIAMWeb.ErrorJSON)
            |> render("error.json", changeset: changeset)
        end
    end
  end

  @doc """
  DELETE /api/hierarchy/nodes/:id
  Deletes a hierarchy node.
  """
  def delete_node(conn, %{"id" => id}) do
    case Hierarchy.get_node(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Node not found"})
      
      node ->
        # Get descendants before deletion for cache invalidation
        descendants = Hierarchy.get_descendants(node.id)
        descendant_ids = Enum.map(descendants, & &1.id)
        
        case Hierarchy.delete_node(node) do
          {:ok, _} ->
            # Invalidate cache for this node and all descendants
            AccessCache.invalidate_node(node.id)
            Enum.each(descendant_ids, &AccessCache.invalidate_node/1)
            
            send_resp(conn, :no_content, "")
          
          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: reason})
        end
    end
  end

  @doc """
  GET /api/hierarchy/nodes/:id/children
  Gets children of a hierarchy node.
  """
  def get_node_children(conn, %{"id" => id}) do
    case Hierarchy.get_node(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Node not found"})
      
      node ->
        children = Hierarchy.get_direct_children(node.id)
        render(conn, :index, nodes: children)
    end
  end

  @doc """
  GET /api/hierarchy/nodes/:id/descendants
  Gets descendants of a hierarchy node.
  """
  def get_node_descendants(conn, %{"id" => id}) do
    case Hierarchy.get_node(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Node not found"})
      
      node ->
        descendants = Hierarchy.get_descendants(node.id)
        render(conn, :index, nodes: descendants)
    end
  end

  @doc """
  GET /api/hierarchy/access
  Lists all access grants.
  """
  def list_access_grants(conn, _params) do
    # Use the existing list_user_access function with all users
    access_grants = Repo.all(XIAM.Hierarchy.Access) |> Repo.preload([:role])
    json(conn, %{data: access_grants})
  end

  @doc """
  POST /api/hierarchy/access
  Creates a new access grant.
  """
  def create_access_grant(conn, %{"node_id" => node_id, "user_id" => user_id, "role_id" => role_id}) do
    case Hierarchy.grant_access(user_id, node_id, role_id) do
      {:ok, access} ->
        # Invalidate cache
        AccessCache.invalidate_node(node_id)
        
        conn
        |> put_status(:created)
        |> json(%{id: access.id, user_id: access.user_id, node_id: node_id, role_id: access.role_id})
      
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  @doc """
  DELETE /api/hierarchy/access/:id
  Deletes an access grant.
  """
  def delete_access_grant(conn, %{"id" => id}) do
    case Repo.get(XIAM.Hierarchy.Access, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Access grant not found"})
      
      access ->
        case Repo.delete(access) do
          {:ok, deleted} ->
            # Invalidate cache
            AccessCache.invalidate_node(deleted.node_id)
            
            send_resp(conn, :no_content, "")
          
          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: reason})
        end
    end
  end

  @doc """
  GET /api/hierarchy/access/node/:node_id
  Lists access grants for a node.
  """
  def list_node_access_grants(conn, %{"node_id" => node_id}) do
    node = Hierarchy.get_node(node_id)
    access_grants = case node do
      nil -> []
      _ -> XIAM.Hierarchy.Access
           |> where(access_path: ^node.path)
           |> Repo.all()
           |> Repo.preload([:role])
    end
    json(conn, %{data: access_grants})
  end

  @doc """
  GET /api/hierarchy/access/user/:user_id
  Lists access grants for a user.
  """
  def list_user_access_grants(conn, %{"user_id" => user_id}) do
    access_grants = Hierarchy.list_user_access(user_id)
    json(conn, %{data: access_grants})
  end

  @doc """
  POST /api/hierarchy/check-access
  Checks if a user has access to a node.
  """
  def check_user_access(conn, %{"user_id" => user_id, "node_id" => node_id}) do
    # Using an existing function that performs this check
    {has_access, node, role} = case Hierarchy.get_node(node_id) do
      nil -> {false, nil, nil}
      node ->
        # Check if user has any access to this node or its ancestors
        access_records = 
          XIAM.Hierarchy.Access
          |> where(user_id: ^user_id)
          |> preload(:role)
          |> Repo.all()
        
        access_paths = Enum.map(access_records, & &1.access_path)
        
        if Enum.empty?(access_paths) do
          {false, node, nil}
        else
          # Using a direct SQL query to check access using ltree
          query = """
            SELECT EXISTS (
              SELECT 1 FROM unnest($1::ltree[]) AS access_path
              WHERE $2::ltree <@ access_path
            )
          """
          
          result = Repo.query!(query, [access_paths, node.path])
          has_access = Enum.at(result.rows, 0) |> Enum.at(0)
          
          # Find the applicable role if access is granted
          role = if has_access do
            # Get the role from the first applicable access grant
            # This could be enhanced to choose the most specific role if needed
            matching_access = Enum.find(access_records, fn access -> 
              String.starts_with?(node.path, access.access_path)
            end)
            matching_access && matching_access.role
          end
          
          {has_access, node, role}
        end
    end
    
    response = %{
      "success" => true,
      "has_access" => has_access
    }
    
    # Add node and role details if they're available
    response = if node do
      node_map = %{
        "id" => node.id,
        "name" => node.name,
        "path" => node.path,
        "node_type" => node.node_type,
        "metadata" => node.metadata || %{},
        "parent_id" => node.parent_id
      }
      Map.put(response, "node", node_map)
    else
      response
    end
    
    response = if role do
      role_map = %{
        "id" => role.id,
        "name" => role.name
      }
      Map.put(response, "role", role_map)
    else
      response
    end
    
    json(conn, response)
  end
  
  # Original functions below
  
  @doc """
  GET /api/v1/hierarchy
  Lists all top-level nodes in the hierarchy.
  """
  def index(conn, _params) do
    # Get only root nodes (those without a parent)
    root_nodes = Hierarchy.list_nodes()
                |> Enum.filter(fn n -> is_nil(n.parent_id) end)
    
    render(conn, :index, nodes: root_nodes)
  end
  
  @doc """
  GET /api/v1/hierarchy/:id
  Returns a specific node along with its direct children.
  """
  def show(conn, %{"id" => id}) do
    case Hierarchy.get_node(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Node not found"})
      
      node ->
        # Get direct children
        children = Hierarchy.get_direct_children(node.id)
        render(conn, :show, node: node, children: children)
    end
  end
  
  @doc """
  GET /api/v1/hierarchy/:id/descendants
  Returns all descendants of a node.
  """
  def descendants(conn, %{"id" => id}) do
    case Hierarchy.get_node(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Node not found"})
      
      node ->
        descendants = Hierarchy.get_descendants(node.id)
        render(conn, :index, nodes: descendants)
    end
  end
  
  @doc """
  GET /api/v1/hierarchy/:id/ancestry
  Returns the ancestor path of a node.
  """
  def ancestry(conn, %{"id" => id}) do
    case Hierarchy.get_node(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Node not found"})
      
      node ->
        ancestry = Hierarchy.get_ancestry(node.id)
        render(conn, :index, nodes: ancestry)
    end
  end
  
  @doc """
  POST /api/v1/hierarchy
  Creates a new node.
  """
  def create(conn, node_params) do
    case Hierarchy.create_node(node_params) do
      {:ok, node} ->
        conn
        |> put_status(:created)
        |> render(:show, node: node, children: [])
      
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(XIAMWeb.ErrorJSON)
        |> render("error.json", changeset: changeset)
      
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end
  
  @doc """
  PUT /api/v1/hierarchy/:id
  Updates a node's attributes.
  """
  def update(conn, %{"id" => id} = params) do
    case Hierarchy.get_node(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Node not found"})
      
      node ->
        case Hierarchy.update_node(node, params) do
          {:ok, updated_node} ->
            render(conn, :show, node: updated_node, children: [])
          
          {:error, %Ecto.Changeset{} = changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> put_view(XIAMWeb.ErrorJSON)
            |> render("error.json", changeset: changeset)
        end
    end
  end
  
  @doc """
  DELETE /api/v1/hierarchy/:id
  Deletes a node and all its descendants.
  """
  def delete(conn, %{"id" => id}) do
    case Hierarchy.get_node(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Node not found"})
      
      node ->
        # Get descendants before deletion for cache invalidation
        descendants = Hierarchy.get_descendants(node.id)
        descendant_ids = Enum.map(descendants, & &1.id)
        
        case Hierarchy.delete_node(node) do
          {:ok, _} ->
            # Invalidate cache for this node and all descendants
            AccessCache.invalidate_node(node.id)
            Enum.each(descendant_ids, &AccessCache.invalidate_node/1)
            
            send_resp(conn, :no_content, "")
          
          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: reason})
        end
    end
  end
  
  @doc """
  POST /api/v1/hierarchy/:id/move
  Moves a node and all its descendants to a new parent.
  """
  def move(conn, %{"id" => id, "parent_id" => parent_id}) do
    case Hierarchy.get_node(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Node not found"})
      
      node ->
        # Convert parent_id to nil if "null" or empty string is provided
        target_parent_id = case parent_id do
          "" -> nil
          "null" -> nil
          _ -> parent_id
        end
        
        case Hierarchy.move_subtree(node, target_parent_id) do
          {:ok, updated_node} ->
            # Invalidate cache
            descendants = Hierarchy.get_descendants(node.id)
            Enum.each([node.id | Enum.map(descendants, & &1.id)], &AccessCache.invalidate_node/1)
            
            render(conn, :show, node: updated_node, children: [])
          
          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: reason})
        end
    end
  end
  
  @doc """
  POST /api/v1/hierarchy/batch/move
  Moves multiple nodes to a new parent.
  """
  def batch_move(conn, %{"node_ids" => node_ids, "parent_id" => parent_id}) do
    # Convert parent_id to nil if "null" or empty string is provided
    target_parent_id = case parent_id do
      "" -> nil
      "null" -> nil
      _ -> parent_id
    end
    
    case BatchOperations.move_batch_nodes(node_ids, target_parent_id) do
      {:ok, results} ->
        json(conn, %{results: results})
      
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end
  
  @doc """
  POST /api/v1/hierarchy/batch/delete
  Deletes multiple nodes and their descendants.
  """
  def batch_delete(conn, %{"node_ids" => node_ids}) do
    case BatchOperations.delete_batch_nodes(node_ids) do
      {:ok, results} ->
        json(conn, %{results: results})
      
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end
  
  @doc """
  GET /api/v1/hierarchy/access/check/:id
  Checks if the current user has access to a node.
  """
  def check_access(conn, %{"id" => node_id}) do
    user_id = conn.assigns.current_user.id
    
    # Use the cached version for performance
    has_access = AccessCache.can_access?(user_id, node_id)
    
    json(conn, %{has_access: has_access})
  end
  
  @doc """
  POST /api/v1/hierarchy/access/batch/check
  Checks access to multiple nodes in one request.
  """
  def batch_check_access(conn, %{"node_ids" => node_ids}) do
    user_id = conn.assigns.current_user.id
    
    access_map = BatchOperations.check_batch_access(user_id, node_ids)
    
    json(conn, %{access: access_map})
  end
  
  @doc """
  POST /api/v1/hierarchy/access/grant
  Grants access to a node for a user.
  """
  def grant_access(conn, %{"node_id" => node_id, "user_id" => user_id, "role_id" => role_id}) do
    case Hierarchy.grant_access(user_id, node_id, role_id) do
      {:ok, access} ->
        # Invalidate cache
        AccessCache.invalidate_node(node_id)
        
        conn
        |> put_status(:created)
        |> json(%{id: access.id, user_id: access.user_id, node_id: node_id, role_id: access.role_id})
      
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end
  
  @doc """
  POST /api/v1/hierarchy/access/batch/grant
  Grants access to multiple nodes for a user.
  """
  def batch_grant_access(conn, %{"user_id" => user_id, "node_ids" => node_ids, "role_id" => role_id}) do
    # BatchOperations.grant_batch_access always returns {:ok, results}
    {:ok, results} = BatchOperations.grant_batch_access(user_id, node_ids, role_id)
    json(conn, %{results: results})
  end
  
  @doc """
  DELETE /api/v1/hierarchy/access/revoke
  Revokes access to a node for a user.
  """
  def revoke_access(conn, %{"node_id" => node_id, "user_id" => user_id}) do
    case Hierarchy.revoke_access(user_id, node_id) do
      {:ok, _} ->
        # Invalidate cache
        AccessCache.invalidate_node(node_id)
        
        send_resp(conn, :no_content, "")
      
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end
  
  @doc """
  POST /api/v1/hierarchy/access/batch/revoke
  Revokes access to multiple nodes for a user.
  """
  def batch_revoke_access(conn, %{"user_id" => user_id, "node_ids" => node_ids}) do
    # BatchOperations.revoke_batch_access always returns {:ok, results}
    {:ok, results} = BatchOperations.revoke_batch_access(user_id, node_ids)
    json(conn, %{results: results})
  end
end
