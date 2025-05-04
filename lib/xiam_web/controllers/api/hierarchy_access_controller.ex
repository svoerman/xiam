defmodule XIAMWeb.API.HierarchyAccessController do
  use XIAMWeb, :controller
  
  alias XIAM.Hierarchy
  
  @doc """
  Checks if the authenticated user has access to a specific node.
  
  Returns JSON response with `{"allowed": true|false}`
  """
  def check_access(conn, %{"node_id" => node_id}) do
    # Extract user_id from the authenticated session
    user_id = conn.assigns.current_user.id
    
    # Use the database function for efficient access check
    has_access = Hierarchy.can_access?(user_id, node_id)
    
    json(conn, %{allowed: has_access})
  end
end
