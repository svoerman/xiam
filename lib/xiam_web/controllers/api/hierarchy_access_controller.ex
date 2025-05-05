defmodule XIAMWeb.API.HierarchyAccessController do
  use XIAMWeb, :controller
  
  alias XIAM.Hierarchy
  
  @doc """
  Checks if the authenticated user has access to a specific node.
  Can accept either a node_id or a path parameter.
  
  Returns JSON response with `{"allowed": true|false}`
  """
  def check_access(conn, params)
  
  def check_access(conn, %{"node_id" => node_id}) do
    # Extract user_id from the authenticated session
    user_id = conn.assigns.current_user.id
    
    # Use the database function for efficient access check
    has_access = Hierarchy.can_access?(user_id, node_id)
    
    json(conn, %{allowed: has_access})
  end

  def check_access(conn, %{"path" => path}) do
    # Extract user_id from the authenticated session
    user_id = conn.assigns.current_user.id
    
    # First get the node by path
    node = Hierarchy.get_node_by_path(path)
    
    if is_nil(node) do
      conn
      |> put_status(:not_found)
      |> json(%{error: "Node not found"})
    else
      # Use the database function for efficient access check
      has_access = Hierarchy.can_access?(user_id, node.id)
      
      json(conn, %{allowed: has_access})
    end
  end

  def check_access(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required parameter. Either 'node_id' or 'path' must be provided"})
  end
end
