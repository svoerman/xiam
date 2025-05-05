defmodule XIAMWeb.Admin.HierarchyLive do
  @moduledoc false
  use XIAMWeb, :live_view
  
  # Import specific UI components needed for modals
  import XIAMWeb.Components.UI.Button
  import XIAMWeb.Components.UI.Modal
  import XIAMWeb.CoreComponents, except: [button: 1, modal: 1]
  import XIAMWeb.Components.UI
  
  # Import business logic modules
  alias XIAM.Hierarchy
  alias XIAM.Hierarchy.{Node, Access, AccessManager}
  alias XIAM.Repo
  alias XIAMWeb.Admin.Components.NodeFormComponent
  
  @impl true
  def mount(_params, _session, socket) do
    # Only load root nodes initially instead of all nodes
    root_nodes = Hierarchy.list_root_nodes()
    roles = Xiam.Rbac.Role |> Repo.all()
    
    # Prepare some common node type suggestions
    # Users can also type their own custom types
    suggested_node_types = [
      "country",
      "company",
      "installation",
      "zone",
      "element",
      "department",
      "team",
      "project",
      "customer",
      "location"
    ]
    
    socket = assign(socket,
      page_title: "Hierarchy Management",
      root_nodes: root_nodes,
      expanded_nodes: %{},  # Tracks which nodes are expanded in UI
      loading_count: Repo.aggregate(Node, :count, :id),  # Total node count for UI feedback
      roles: roles,
      suggested_node_types: suggested_node_types,
      selected_node: nil,
      node_changeset: Node.changeset(%Node{}, %{}),
      access_changeset: Access.changeset(%Access{}, %{}),
      show_modal: false,
      modal_type: nil,
      users: [],  # Will be populated when granting access
      page: 1,
      per_page: 50,
      search_term: nil,
      access_grants: nil
    )
    
    {:ok, socket}
  end
  
  @impl true
  def handle_params(params, _url, socket) do
    # If node_id is passed, select that node
    socket = case params do
      %{"node_id" => node_id} ->
        case Hierarchy.get_node(node_id) do
          nil -> 
            socket 
            |> put_flash(:error, "Node not found")
          node -> 
            # Get node children for display
            children = Hierarchy.get_direct_children(node.id)
            socket = assign(socket, selected_node: node, children: children)
            # Also load access grants for this node
            load_node_access(socket, node)
        end
      _ -> socket
    end
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("show_new_node_modal", %{"parent-id" => parent_id}, socket) do
    # Create node with parent ID
    changeset = Node.changeset(%Node{}, %{parent_id: parent_id})
    
    {:noreply, socket
      |> assign(:show_modal, true)
      |> assign(:modal_type, :new_node)
      |> assign(:node_changeset, changeset)
      |> assign(:node, nil)
    }
  end
  
  @impl true
  def handle_event("show_new_node_modal", _params, socket) do
    # Create a root node (no parent)
    changeset = Node.changeset(%Node{}, %{})
    
    {:noreply, socket
      |> assign(:show_modal, true)
      |> assign(:modal_type, :new_node)
      |> assign(:node_changeset, changeset)
      |> assign(:node, nil)
    }
  end
  
  def handle_event("show_edit_node_modal", %{"id" => id}, socket) do
    case Hierarchy.get_node(id) do
      nil ->
        {:noreply, socket |> put_flash(:error, "Node not found")}
      node ->
        # Convert the metadata map to JSON string for the form
        metadata_json = case node.metadata do
          nil -> ""
          map when is_map(map) -> Jason.encode!(map, pretty: true)
          other -> inspect(other) # Handle any other unexpected type
        end
        
        # Create a modified node with metadata as a string for the changeset
        node_params = %{
          "id" => node.id,
          "name" => node.name,
          "node_type" => node.node_type,
          "metadata" => metadata_json
        }
        
        # Create a changeset with the stringified metadata
        changeset = Node.changeset(node, node_params)
        {:noreply, assign(socket,
          show_modal: true,
          modal_type: :edit_node,
          node_changeset: changeset,
          node: node
        )}
    end
  end
  
  def handle_event("show_grant_access_modal", %{"id" => id}, socket) do
    case Hierarchy.get_node(id) do
      nil ->
        {:noreply, socket |> put_flash(:error, "Node not found")}
      node ->
        # Get a list of users to potentially grant access to
        users = XIAM.Users.list_users()
        
        changeset = Access.changeset(%Access{}, %{node_id: node.id})
        
        {:noreply, assign(socket,
          show_modal: true,
          modal_type: :grant_access,
          selected_node: node,
          users: users,
          access_changeset: changeset
        )}
    end
  end
  
  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket,
      show_modal: false,
      modal_type: nil
    )}
  end
  
  def handle_event("validate_node", %{"node" => node_params}, socket) do
    socket = 
      socket
      |> NodeFormComponent.validate_changeset(node_params)
      
    {:noreply, socket}
  end
  
  def handle_event("save_node", %{"node" => node_params}, socket) do
    case socket.assigns.modal_type do
      :new_node ->
        # Convert string params to proper types
        node_params = convert_node_params(node_params)
        
        case Hierarchy.create_node(node_params) do
          {:ok, node} ->
            socket = refresh_ui_after_node_change(socket, node)
            
            {:noreply, socket
              |> assign(show_modal: false, modal_type: nil)
              |> put_flash(:info, "Node created successfully")}
              
          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, node_changeset: changeset)}
            
          {:error, reason} ->
            {:noreply, socket
              |> put_flash(:error, "Error creating node: #{inspect(reason)}")
              |> assign(show_modal: false)}
        end
        
      :edit_node ->
        node = socket.assigns.node
        
        # Convert string params to proper types
        node_params = convert_node_params(node_params)
        
        case Hierarchy.update_node(node, node_params) do
          {:ok, updated_node} ->
            socket = refresh_ui_after_node_change(socket, updated_node)
            
            {:noreply, socket
              |> assign(show_modal: false, modal_type: nil)
              |> put_flash(:info, "Node updated successfully")}
              
          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, node_changeset: changeset)}
        end
        
      _ ->
        {:noreply, socket}
    end
  end
  
  def handle_event("toggle_node", %{"id" => id}, socket) do
    node_id = id
    
    socket = 
      if Map.has_key?(socket.assigns.expanded_nodes, node_id) do
        # Node is expanded, collapse it by removing it from expanded_nodes
        expanded_nodes = Map.delete(socket.assigns.expanded_nodes, node_id)
        assign(socket, expanded_nodes: expanded_nodes)
      else
        # Node is collapsed, expand it by loading its children
        children = Hierarchy.get_direct_children(node_id)
        expanded_nodes = Map.put(socket.assigns.expanded_nodes, node_id, children)
        assign(socket, expanded_nodes: expanded_nodes)
      end
      
    {:noreply, socket}
  end
  
  def handle_event("select_node", %{"id" => id}, socket) do
    node = Hierarchy.get_node(id)
    
    if node do
      children = Hierarchy.get_direct_children(node.id)
      socket = assign(socket, selected_node: node, children: children)
      socket = load_node_access(socket, node)
      
      # If not already expanded, expand this node
      socket = 
        if not Map.has_key?(socket.assigns.expanded_nodes, id) do
          expanded_nodes = Map.put(socket.assigns.expanded_nodes, id, children)
          assign(socket, expanded_nodes: expanded_nodes)
        else
          socket
        end
        
      # Navigate to the node's page to make it bookmarkable
      {:noreply, push_patch(socket, to: "/admin/hierarchy?node_id=#{node.id}")}
    else
      {:noreply, socket |> put_flash(:error, "Node not found")}
    end
  end
  
  def handle_event("delete_node", %{"id" => id}, socket) do
    case Hierarchy.get_node(id) do
      nil ->
        {:noreply, socket |> put_flash(:error, "Node not found")}
      node ->
        parent_id = node.parent_id
        
        case Hierarchy.delete_node(node) do
          {:ok, _} ->
            socket = 
              cond do
                # If the deleted node was selected, clear selection
                socket.assigns.selected_node && socket.assigns.selected_node.id == id ->
                  assign(socket, selected_node: nil, children: nil, access_grants: nil)
                
                # If the parent of the deleted node is selected, refresh its children list
                socket.assigns.selected_node && socket.assigns.selected_node.id == parent_id ->
                  children = Hierarchy.get_direct_children(parent_id)
                  assign(socket, children: children)
                
                # No updates needed
                true ->
                  socket
              end
              
            # Update expanded_nodes to remove the deleted node
            expanded_nodes = Map.delete(socket.assigns.expanded_nodes, id)
            
            # If this was a child node, refresh its parent's children
            socket = 
              if parent_id do
                # Get fresh data for parent's children
                parent_children = Hierarchy.get_direct_children(parent_id)
                expanded_nodes = Map.put(expanded_nodes, "#{parent_id}", parent_children)
                assign(socket, expanded_nodes: expanded_nodes)
              else
                # This was a root node, refresh root nodes
                root_nodes = Hierarchy.list_root_nodes()
                assign(socket, root_nodes: root_nodes, expanded_nodes: expanded_nodes)
              end
              
            # Update total count
            loading_count = Repo.aggregate(Node, :count, :id)
            socket = assign(socket, loading_count: loading_count)
            
            {:noreply, socket |> put_flash(:info, "Node deleted successfully")}
            
          {:error, reason} ->
            {:noreply, socket |> put_flash(:error, "Error deleting node: #{inspect(reason)}")}
        end
    end
  end
  
  def handle_event("grant_access", %{"access" => access_params}, socket) do
    node_id = access_params["node_id"]
    user_id = access_params["user_id"]
    role_id = access_params["role_id"]
    
    # Convert IDs to integers
    node_id = if is_binary(node_id), do: String.to_integer(node_id), else: node_id
    user_id = if is_binary(user_id), do: String.to_integer(user_id), else: user_id
    role_id = if is_binary(role_id), do: String.to_integer(role_id), else: role_id
    
    # First check if access already exists
    node = Hierarchy.get_node(node_id)
    existing_access = Repo.get_by(Access, user_id: user_id, access_path: node.path)
    
    case AccessManager.grant_access(user_id, node_id, role_id) do
      {:ok, _access} ->
        # Reload access grants for the selected node
        socket = 
          if socket.assigns.selected_node && socket.assigns.selected_node.id == node_id do
            load_node_access(socket, socket.assigns.selected_node)
          else
            socket
          end
        
        # Create appropriate message based on whether this was a new or updated access
        message = if existing_access, do: "Access role updated successfully", else: "Access granted successfully"
          
        {:noreply, socket
          |> assign(show_modal: false, modal_type: nil)
          |> put_flash(:info, message)}
          
      {:error, reason} ->
        {:noreply, socket |> put_flash(:error, "Error granting access: #{inspect(reason)}")}
    end
  end
  
  def handle_event("revoke_access", %{"user-id" => user_id}, socket) do
    # Convert to integer
    user_id = if is_binary(user_id), do: String.to_integer(user_id), else: user_id
    
    # First get the access record based on the user_id and node path
    node_path = socket.assigns.selected_node.path
    case Repo.get_by(Access, user_id: user_id, access_path: node_path) do
      nil ->
        {:noreply, socket |> put_flash(:error, "Access not found")}
        
      access ->
        # Now revoke the access by ID
        case AccessManager.revoke_access(access.id) do
          {:ok, _} ->
            # Reload access grants for the selected node
            socket = 
              if socket.assigns.selected_node do
                load_node_access(socket, socket.assigns.selected_node)
              else
                socket
              end
              
            {:noreply, socket |> put_flash(:info, "Access revoked successfully")}
            
          {:error, reason} ->
            {:noreply, socket |> put_flash(:error, "Error revoking access: #{inspect(reason)}")}
        end
    end
  end
  
  def handle_event("search_nodes", %{"search" => %{"term" => term}}, socket) do
    if String.trim(term) == "" do
      {:noreply, assign(socket, search_term: nil)}
    else
      search_results = Hierarchy.search_nodes(term)
      {:noreply, assign(socket, search_term: term, search_results: search_results)}
    end
  end
  
  def handle_event("search", %{"search" => %{"term" => term}}, socket) do
    if String.trim(term) == "" do
      {:noreply, assign(socket, search_term: nil, search_results: nil)}
    else
      search_results = Hierarchy.search_nodes(term)
      {:noreply, assign(socket, search_term: term, search_results: search_results)}
    end
  end
  
  def handle_event("clear_search", _, socket) do
    {:noreply, assign(socket, search_term: nil, search_results: nil)}
  end
  
  # Private functions

  defp convert_node_params(params) do
    # Handle metadata conversion from JSON
    params = 
      if params["metadata"] && params["metadata"] != "" do
        try do
          metadata = Jason.decode!(params["metadata"])
          Map.put(params, "metadata", metadata)
        rescue
          _ -> params
        end
      else
        params
      end
      
    # Handle empty string for parent_id (convert to nil for root nodes)
    params =
      if Map.has_key?(params, "parent_id") && params["parent_id"] == "" do
        Map.put(params, "parent_id", nil)
      else
        params
      end
      
    params
  end
  
  defp refresh_ui_after_node_change(socket, node) do
    # Refresh the appropriate parts of the UI with fresh data
    is_root = node.parent_id == nil
    
    socket = cond do
      # If we created/updated a root node, refresh the root nodes list
      is_root ->
        root_nodes = Hierarchy.list_root_nodes()
        assign(socket, root_nodes: root_nodes)
        
      # If we added/updated a child to the selected node, refresh its children
      socket.assigns.selected_node && node.parent_id == socket.assigns.selected_node.id ->
        # Get fresh children data
        children = Hierarchy.get_direct_children(socket.assigns.selected_node.id)
        # Ensure the parent is expanded to show the new/updated child
        expanded_nodes = Map.put(socket.assigns.expanded_nodes, "#{node.parent_id}", children)
        
        socket
        |> assign(children: children)
        |> assign(expanded_nodes: expanded_nodes)
        
      # If we added/updated a node somewhere else in the hierarchy
      true ->
        # Expand the parent to show the new/updated node
        # Get fresh children data
        children = Hierarchy.get_direct_children(node.parent_id)
        expanded_nodes = Map.put(socket.assigns.expanded_nodes, "#{node.parent_id}", children)
        
        assign(socket, expanded_nodes: expanded_nodes)
    end
    
    # Update the node count
    loading_count = Repo.aggregate(Node, :count, :id)
    assign(socket, loading_count: loading_count)
  end
  
  defp load_node_access(socket, node) do
    # Execute direct SQL query to get access info with email and role name
    query = """
    SELECT ha.*, u.email, r.name as role_name 
    FROM hierarchy_access ha 
    JOIN users u ON ha.user_id = u.id
    JOIN roles r ON ha.role_id = r.id
    WHERE ha.access_path = $1
    ORDER BY ha.inserted_at DESC
    """
    
    case Ecto.Adapters.SQL.query(Repo, query, [node.path]) do
      {:ok, %{rows: rows, columns: columns}} ->
        # Convert rows to maps with proper keys
        access_grants = Enum.map(rows, fn row ->
          columns
          |> Enum.zip(row)
          |> Map.new(fn {col, val} -> {col, val} end)
        end)
        
        assign(socket, node_access: access_grants)
        
      _ ->
        # Fallback to regular access list
        access_grants = AccessManager.list_node_access(node.id)
        assign(socket, node_access: access_grants)
    end
  end
  

end
