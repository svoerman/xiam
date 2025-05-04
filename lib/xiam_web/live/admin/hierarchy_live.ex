defmodule XIAMWeb.Admin.HierarchyLive do
  use XIAMWeb, :live_view
  
  import XIAMWeb.Components.UI.Button
  import XIAMWeb.Components.UI.Modal
  import XIAMWeb.CoreComponents, except: [button: 1, modal: 1]
  import XIAMWeb.Components.UI
  
  alias XIAM.Hierarchy
  alias XIAM.Hierarchy.Node
  alias XIAM.Hierarchy.Access
  alias XIAM.Repo
  
  @impl true
  def mount(_params, _session, socket) do
    nodes = Hierarchy.list_nodes()
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
      nodes: nodes,
      roles: roles,
      suggested_node_types: suggested_node_types,
      selected_node: nil,
      node_changeset: Node.changeset(%Node{}, %{}),
      access_changeset: Access.changeset(%Access{}, %{}),
      show_modal: false,
      modal_type: nil,
      users: []  # Will be populated when granting access
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
  def handle_event("show_new_node_modal", _params, socket) do
    changeset = Node.changeset(%Node{}, %{})
    
    # If a node is selected, pre-fill parent_id
    changeset = case socket.assigns.selected_node do
      nil -> changeset
      node -> Ecto.Changeset.put_change(changeset, :parent_id, node.id)
    end
    
    {:noreply, assign(socket,
      show_modal: true,
      modal_type: :new_node,
      node_changeset: changeset
    )}
  end
  
  def handle_event("show_edit_node_modal", %{"id" => id}, socket) do
    case Hierarchy.get_node(id) do
      nil ->
        {:noreply, socket |> put_flash(:error, "Node not found")}
      node ->
        changeset = Node.changeset(node, %{})
        {:noreply, assign(socket,
          show_modal: true,
          modal_type: :edit_node,
          node_changeset: changeset
        )}
    end
  end
  
  def handle_event("show_move_node_modal", %{"id" => id}, socket) do
    # Get all nodes that could be potential parents (cannot move to own descendants)
    case Hierarchy.get_node(id) do
      nil ->
        {:noreply, socket |> put_flash(:error, "Node not found")}
      node ->
        # Get all nodes except this one and its descendants
        all_nodes = Hierarchy.list_nodes()
        descendants = Hierarchy.get_descendants(node.id)
        descendant_ids = Enum.map(descendants, & &1.id) ++ [node.id]
        
        potential_parents = Enum.reject(all_nodes, fn n -> 
          Enum.member?(descendant_ids, n.id)
        end)
        
        {:noreply, assign(socket,
          show_modal: true,
          modal_type: :move_node,
          selected_node: node,
          potential_parents: potential_parents
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
        
        changeset = Access.changeset(%Access{}, %{})
        
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
  
  def handle_event("save_node", %{"node" => node_params}, socket) do
    case socket.assigns.modal_type do
      :new_node ->
        # Convert string params to proper types
        node_params = convert_node_params(node_params)
        
        case Hierarchy.create_node(node_params) do
          {:ok, _node} ->
            nodes = Hierarchy.list_nodes()
            
            # If we have a selected node, refresh its children
            socket = case socket.assigns.selected_node do
              nil -> socket
              selected_node -> 
                children = Hierarchy.get_direct_children(selected_node.id)
                assign(socket, children: children)
            end
            
            {:noreply, socket
              |> assign(nodes: nodes, show_modal: false)
              |> put_flash(:info, "Node created successfully")}
              
          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, node_changeset: changeset)}
            
          {:error, reason} ->
            {:noreply, socket
              |> put_flash(:error, "Error creating node: #{inspect(reason)}")
              |> assign(show_modal: false)}
        end
        
      :edit_node ->
        node_params = convert_node_params(node_params)
        node = Repo.get(Node, node_params.id)
        
        case Hierarchy.update_node(node, node_params) do
          {:ok, _node} ->
            nodes = Hierarchy.list_nodes()
            
            # If we have a selected node, refresh its children
            socket = case socket.assigns.selected_node do
              nil -> socket
              selected_node -> 
                children = Hierarchy.get_direct_children(selected_node.id)
                assign(socket, children: children)
            end
            
            {:noreply, socket
              |> assign(nodes: nodes, show_modal: false)
              |> put_flash(:info, "Node updated successfully")}
              
          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, node_changeset: changeset)}
        end
        
      _ ->
        {:noreply, socket |> put_flash(:error, "Invalid action")}
    end
  end
  
  def handle_event("move_node", %{"move" => %{"parent_id" => parent_id}}, socket) do
    node = socket.assigns.selected_node
    parent_id = String.to_integer(parent_id)
    
    case Hierarchy.move_subtree(node, parent_id) do
      {:ok, _} ->
        nodes = Hierarchy.list_nodes()
        
        socket = case socket.assigns.selected_node do
          nil -> socket
          selected_node -> 
            # Get the moved node to update the selection
            updated_node = Hierarchy.get_node(selected_node.id)
            children = Hierarchy.get_direct_children(updated_node.id)
            assign(socket, selected_node: updated_node, children: children)
        end
        
        {:noreply, socket
          |> assign(nodes: nodes, show_modal: false)
          |> put_flash(:info, "Node moved successfully")}
          
      {:error, reason} ->
        {:noreply, socket
          |> put_flash(:error, "Error moving node: #{inspect(reason)}")
          |> assign(show_modal: false)}
    end
  end
  
  def handle_event("grant_access", %{"access" => access_params}, socket) do
    node = socket.assigns.selected_node
    
    user_id = String.to_integer(access_params["user_id"])
    role_id = String.to_integer(access_params["role_id"])
    
    case Hierarchy.grant_access(user_id, node.id, role_id) do
      {:ok, _} ->
        {:noreply, socket
          |> assign(show_modal: false)
          |> put_flash(:info, "Access granted successfully")}
          
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, access_changeset: changeset)}
        
      {:error, reason} ->
        {:noreply, socket
          |> put_flash(:error, "Error granting access: #{inspect(reason)}")
          |> assign(show_modal: false)}
    end
  end
  
  def handle_event("delete_node", %{"id" => id}, socket) do
    case Hierarchy.get_node(id) do
      nil ->
        {:noreply, socket |> put_flash(:error, "Node not found")}
      node ->
        case Hierarchy.delete_node(node) do
          {:ok, _} ->
            nodes = Hierarchy.list_nodes()
            
            # If we deleted the selected node, clear selection
            socket = if socket.assigns.selected_node && socket.assigns.selected_node.id == node.id do
              assign(socket, selected_node: nil)
            else
              socket
            end
            
            {:noreply, socket
              |> assign(nodes: nodes)
              |> put_flash(:info, "Node and all descendants deleted successfully")}
              
          {:error, reason} ->
            {:noreply, socket |> put_flash(:error, "Error deleting node: #{inspect(reason)}")}
        end
    end
  end
  
  def handle_event("select_node", %{"id" => id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/hierarchy?node_id=#{id}")}
  end
  
  def handle_event("revoke_access", %{"user_id" => user_id}, socket) do
    node = socket.assigns.selected_node
    user_id = String.to_integer(user_id)
    
    case Hierarchy.revoke_access(user_id, node.id) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "Access revoked successfully")}
        
      {:error, reason} ->
        {:noreply, socket |> put_flash(:error, "Error revoking access: #{inspect(reason)}")}
    end
  end
  
  # Helper to load node access for the view
  defp load_node_access(socket, node) do
    # Get all access grants for this node - using string interpolation to avoid pin operator issues
    query = """
    SELECT ha.*, u.email, r.name as role_name 
    FROM hierarchy_access ha 
    JOIN users u ON ha.user_id = u.id
    JOIN roles r ON ha.role_id = r.id
    WHERE ha.access_path = $1
    """
    result = Repo.query!(query, [node.path])
    
    # Map the results to a simple structure
    accesses = Enum.map(result.rows, fn [id, user_id, _access_path, role_id, _inserted_at, _updated_at, email, role_name] -> 
      %{
        id: id,
        user_id: user_id,
        user: %{email: email},
        role: %{name: role_name, id: role_id}
      }
    end)
    
    assign(socket, node_access: accesses)
  end

  # Helper function to recursively render children in the template
  def render_children(assigns) do
    children = Enum.filter(assigns.all_nodes, fn n -> n.parent_id == assigns.parent.id end)
    
    assigns = assign(assigns, :children, children)
    
    ~H"""
    <%= if length(@children) > 0 do %>
      <ul class="pl-6 mt-1 space-y-1">
        <%= for child <- @children do %>
          <li>
            <div class={[
              "flex items-center p-2 rounded cursor-pointer",
              @selected_node && @selected_node.id == child.id && "bg-blue-100"
            ]}>
              <span phx-click="select_node" phx-value-id={child.id} class="flex-grow font-medium">
                <%= child.name %>
              </span>
              <span class="text-xs text-gray-500 px-2">
                <%= XIAM.Hierarchy.Node.node_type_name(child.node_type) %>
              </span>
              <div class="flex items-center space-x-1">
                <button phx-click="show_edit_node_modal" phx-value-id={child.id} class="text-gray-600 hover:text-blue-500">
                  <.icon name="hero-pencil-square" class="w-4 h-4" />
                </button>
                <button phx-click="show_move_node_modal" phx-value-id={child.id} class="text-gray-600 hover:text-blue-500">
                  <.icon name="hero-arrow-path" class="w-4 h-4" />
                </button>
                <button phx-click="delete_node" phx-value-id={child.id} data-confirm="Are you sure? This will delete this node and ALL descendants." class="text-gray-600 hover:text-red-500">
                  <.icon name="hero-trash" class="w-4 h-4" />
                </button>
              </div>
            </div>
            
            <.render_children
              parent={child}
              all_nodes={@all_nodes}
              selected_node={@selected_node}
            />
          </li>
        <% end %>
      </ul>
    <% end %>
    """
  end
  
  # Convert string params to the proper types
  defp convert_node_params(params) do
    params
    |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
    # No longer converting node_type to integer since it's now a string
    |> Map.update(:parent_id, nil, fn
      "" -> nil
      id -> String.to_integer(id)
    end)
    |> Map.update(:id, nil, fn
      nil -> nil
      "" -> nil
      id -> String.to_integer(id)
    end)
    |> Map.update(:metadata, %{}, fn
      nil -> %{}
      "" -> %{}
      json when is_binary(json) ->
        case Jason.decode(json) do
          {:ok, map} -> map
          _ -> %{}
        end
      map -> map
    end)
  end
end
