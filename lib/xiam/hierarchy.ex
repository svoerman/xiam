defmodule XIAM.Hierarchy do
  @moduledoc """
  The Hierarchy context provides functions for managing hierarchical entities and access control.
  It uses PostgreSQL's ltree extension for efficient traversal and access checking.
  """
  import Ecto.Query
  alias XIAM.Repo
  alias XIAM.Hierarchy.{Node, Access}
  
  #
  # Node Management
  #
  
  @doc """
  Creates a new node. If parent_id is provided, it will be created as a child of that node.
  If no parent_id is provided, it will be created as a root node.
  """
  def create_node(%{parent_id: parent_id} = attrs) when not is_nil(parent_id) do
    # Handle both string and atom keys consistently
    attrs = for {key, val} <- attrs, into: %{}, do: {to_string(key), val}
    name = attrs["name"]
    
    # Build path from parent's path
    parent = get_node(parent_id)
    
    if is_nil(parent) do
      {:error, :parent_not_found}
    else
      path = build_child_path(parent.path, name)
      
      %Node{}
      |> Node.changeset(attrs)
      |> Ecto.Changeset.put_change(:path, path)
      |> Repo.insert()
    end
  end
  
  def create_node(attrs) do
    # Handle both string and atom keys
    attrs = for {key, val} <- attrs, into: %{}, do: {to_string(key), val}
    
    # Get name from attrs using string key
    name = attrs["name"]
    
    # Check if there's a parent_id (could be as string key)
    parent_id = attrs["parent_id"]
    
    if parent_id do
      # If there's a parent, delegate to the parent version
      create_node(%{parent_id: parent_id, name: name, node_type: attrs["node_type"], metadata: attrs["metadata"]})
    else
      # Create root node
      path = sanitize_name(name)
      
      %Node{}
      |> Node.changeset(attrs)
      |> Ecto.Changeset.put_change(:path, path)
      |> Repo.insert()
    end
  end
  
  @doc """
  Gets a node by ID.
  """
  def get_node(id), do: Repo.get(Node, id)
  
  @doc """
  Gets a node by its path.
  """
  def get_node_by_path(path) do
    Repo.get_by(Node, path: path)
  end
  
  @doc """
  Lists all nodes, ordered by path.
  """
  def list_nodes do
    Node
    |> order_by([n], n.path)
    |> Repo.all()
  end
  
  @doc """
  Gets direct children of a node.
  """
  def get_direct_children(parent_id) do
    Node
    |> where([n], n.parent_id == ^parent_id)
    |> order_by([n], n.path)
    |> Repo.all()
  end
  
  @doc """
  Gets all descendants of a node (children, grandchildren, etc).
  """
  def get_descendants(parent_id) do
    parent = get_node(parent_id)
    
    if is_nil(parent) do
      []
    else
      query = """
      SELECT * FROM hierarchy_nodes
      WHERE path::ltree <@ $1::ltree
      AND id != $2
      ORDER BY path
      """
      
      result = Repo.query!(query, [parent.path, parent.id])
      
      Enum.map(result.rows, fn row ->
        # Map row data to Node struct
        id = Enum.at(row, 0)
        path = Enum.at(row, 1)
        parent_id = Enum.at(row, 2)
        node_type = Enum.at(row, 3)
        name = Enum.at(row, 4)
        metadata = Enum.at(row, 5)
        inserted_at = Enum.at(row, 6)
        updated_at = Enum.at(row, 7)
        
        %Node{
          id: id,
          path: path,
          parent_id: parent_id,
          node_type: node_type,
          name: name,
          metadata: metadata,
          inserted_at: inserted_at,
          updated_at: updated_at
        }
      end)
    end
  end
  
  @doc """
  Gets the ancestry path of a node (all parents up to root).
  """
  def get_ancestry(node_id) do
    node = get_node(node_id)
    
    if is_nil(node) do
      []
    else
      query = """
      SELECT * FROM hierarchy_nodes
      WHERE $1::ltree <@ path::ltree
      AND id != $2
      ORDER BY path
      """
      
      result = Repo.query!(query, [node.path, node.id])
      
      Enum.map(result.rows, fn row ->
        # Map row data to Node struct
        id = Enum.at(row, 0)
        path = Enum.at(row, 1)
        parent_id = Enum.at(row, 2)
        node_type = Enum.at(row, 3)
        name = Enum.at(row, 4)
        metadata = Enum.at(row, 5)
        inserted_at = Enum.at(row, 6)
        updated_at = Enum.at(row, 7)
        
        %Node{
          id: id,
          path: path,
          parent_id: parent_id,
          node_type: node_type,
          name: name,
          metadata: metadata,
          inserted_at: inserted_at,
          updated_at: updated_at
        }
      end)
    end
  end
  
  @doc """
  Updates a node's attributes. Note that this doesn't change the node's position
  in the hierarchy. Use move_subtree/2 for that.
  """
  def update_node(%Node{} = node, attrs) do
    node
    |> Node.changeset(attrs)
    |> Repo.update()
  end
  
  @doc """
  Moves a node and all its descendants to a new parent.
  """
  def move_subtree(%Node{} = node, new_parent_id) do
    new_parent = get_node(new_parent_id)
    
    if is_nil(new_parent) do
      {:error, :parent_not_found}
    else
      # Verify we're not creating a cycle by moving a node to its own descendant
      # Check if new_parent is a descendant of the node we're trying to move
      if node.id == new_parent_id or is_descendant?(new_parent_id, node.id) do
        {:error, :would_create_cycle}
      else
        # In a transaction, update the node and all descendants
        Repo.transaction(fn ->
          new_path = build_child_path(new_parent.path, node.name)
          old_path = node.path
          
          # Update the moved node
          changeset = Node.changeset(node, %{parent_id: new_parent_id})
          node = Ecto.Changeset.put_change(changeset, :path, new_path) |> Repo.update!()
          
          # Update all descendants
          Repo.query!("""
            UPDATE hierarchy_nodes
            SET path = text2ltree($1 || subltree(path::ltree, nlevel($2::ltree) - 1, nlevel(path::ltree) - nlevel($2::ltree) + 1)::text)
            WHERE path::ltree <@ $2::ltree
            AND id != $3
          """, [new_path, old_path, node.id])
          
          node
        end)
      end
    end
  end
  
  @doc """
  Deletes a node and all its descendants.
  """
  def delete_node(%Node{} = node) do
    Repo.transaction(fn ->
      # Delete all descendants
      Repo.query!("""
        DELETE FROM hierarchy_nodes
        WHERE path::ltree <@ $1::ltree
      """, [node.path])
      
      {:ok, node}
    end)
  end
  
  # Note: list_nodes/0 and update_node/2 functions already exist elsewhere in this file
  
  @doc """
  Checks if a node is a descendant of another node.
  """
  def is_descendant?(descendant_id, ancestor_id) do
    descendant = get_node(descendant_id)
    ancestor = get_node(ancestor_id)
    
    if is_nil(descendant) or is_nil(ancestor) do
      false
    else
      result = Repo.query!("SELECT $1::ltree <@ $2::ltree", [descendant.path, ancestor.path])
      Enum.at(result.rows, 0) |> Enum.at(0)
    end
  end
  
  #
  # Access Management
  #
  
  @doc """
  Grants a user access to a node (and implicitly to all its descendants).
  """
  def grant_access(user_id, node_id, role_id) do
    node = get_node(node_id)
    
    if is_nil(node) do
      {:error, :node_not_found}
    else
      %Access{}
      |> Access.changeset(%{
        user_id: user_id,
        access_path: node.path,
        role_id: role_id
      })
      |> Repo.insert(on_conflict: :replace_all, conflict_target: [:user_id, :access_path])
    end
  end
  
  @doc """
  Revokes a user's access to a specific node.
  """
  def revoke_access(user_id, node_id) do
    node = get_node(node_id)
    
    if is_nil(node) do
      {:error, :node_not_found}
    else
      {count, _} = 
        Access
        |> where(user_id: ^user_id, access_path: ^node.path)
        |> Repo.delete_all()
      
      {:ok, count}
    end
  end
  
  @doc """
  Lists all access grants for a user.
  """
  def list_user_access(user_id) do
    Access
    |> where(user_id: ^user_id)
    |> preload([:role])
    |> Repo.all()
  end
  
  @doc """
  Lists all access grants across the system.
  Used for the GET /api/hierarchy/access endpoint.
  """
  def list_access_grants do
    Access
    |> preload([:role])
    |> Repo.all()
  end
  
  @doc """
  Gets a specific access grant by ID.
  """
  def get_access_grant(id) do
    Repo.get(Access, id)
  end
  
  @doc """
  Lists all access grants for a specific node.
  """
  def list_node_access_grants(node_id) do
    node = get_node(node_id)
    
    if is_nil(node) do
      []
    else
      Access
      |> where(access_path: ^node.path)
      |> preload([:role])
      |> Repo.all()
    end
  end
  
  @doc """
  Lists all access grants for a specific user.
  """
  def list_user_access_grants(user_id) do
    Access
    |> where(user_id: ^user_id)
    |> preload([:role])
    |> Repo.all()
  end
  
  @doc """
  Deletes an access grant.
  """
  def delete_access_grant(%Access{} = access) do
    Repo.delete(access)
  end
  
  @doc """
  Checks if a user has access to a specific node.
  Used for the POST /api/hierarchy/check-access endpoint.
  """
  def can_user_access(user_id, node_id) do
    node = get_node(node_id)
    
    if is_nil(node) do
      false
    else
      # Get all access paths for the user
      access_paths = 
        Access
        |> where(user_id: ^user_id)
        |> select([a], a.access_path)
        |> Repo.all()
      
      if Enum.empty?(access_paths) do
        false
      else
        # Check if any access path is an ancestor of the node's path
        query = """
          SELECT EXISTS (
            SELECT 1 FROM unnest($1::ltree[]) AS access_path
            WHERE $2::ltree <@ access_path
          )
        """
        
        result = Repo.query!(query, [access_paths, node.path])
        Enum.at(result.rows, 0) |> Enum.at(0)
      end
    end
  end
  
  @doc """
  Lists all nodes a user has access to.
  """
  def list_accessible_nodes(user_id) do
    # Get all access paths for the user
    access_paths = 
      from(a in Access, where: a.user_id == ^user_id, select: a.access_path)
      |> Repo.all()
    
    if Enum.empty?(access_paths) do
      []
    else
      # Convert to a condition that matches any node that is a descendant of any access path
      paths_condition = Enum.map_join(access_paths, " OR ", fn path ->
        "path::ltree <@ '#{path}'::ltree"
      end)
      
      query = "SELECT * FROM hierarchy_nodes WHERE #{paths_condition} ORDER BY path"
      result = Repo.query!(query, [])
      
      Enum.map(result.rows, fn row ->
        # Map row data to Node struct
        id = Enum.at(row, 0)
        path = Enum.at(row, 1)
        parent_id = Enum.at(row, 2)
        node_type = Enum.at(row, 3)
        name = Enum.at(row, 4)
        metadata = Enum.at(row, 5)
        inserted_at = Enum.at(row, 6)
        updated_at = Enum.at(row, 7)
        
        %Node{
          id: id,
          path: path,
          parent_id: parent_id,
          node_type: node_type,
          name: name,
          metadata: metadata,
          inserted_at: inserted_at,
          updated_at: updated_at
        }
      end)
    end
  end
  
  @doc """
  Checks if a user has access to a specific node.
  Handles both string and integer IDs for user_id and node_id.
  """
  def can_access?(user_id, node_id) do
    # Convert IDs to integers if they're strings
    user_id = if is_binary(user_id), do: String.to_integer(user_id), else: user_id
    node_id = if is_binary(node_id), do: String.to_integer(node_id), else: node_id
    
    result = Repo.query!("SELECT can_user_access($1, $2)", [user_id, node_id])
    
    [[has_access]] = result.rows
    has_access
  end
  
  #
  # Helper Functions
  #
  
  @doc """
  Builds a child path by concatenating the parent path with the sanitized name.
  """
  def build_child_path(parent_path, name) do
    sanitized = sanitize_name(name)
    "#{parent_path}.#{sanitized}"
  end
  
  @doc """
  Sanitizes a name to be used in an ltree path.
  Replaces non-alphanumeric characters with underscores.
  """
  def sanitize_name(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_]/, "_")
  end
  
  def sanitize_name(name) do
    to_string(name)
    |> sanitize_name()
  end
end
