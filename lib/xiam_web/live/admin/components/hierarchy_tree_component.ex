defmodule XIAMWeb.Admin.Components.HierarchyTreeComponent do
  @moduledoc """
  LiveView component for displaying and interacting with the hierarchy tree.
  Extracted from the original HierarchyLive module to improve maintainability.
  """
  use XIAMWeb, :live_component
  
  # We're not using Button directly in this module, so we can comment it out
  # import XIAMWeb.Components.UI.Button
  import XIAMWeb.Components.UI.Dropdown
  import XIAMWeb.CoreComponents, except: [button: 1, dropdown: 1]
  import XIAMWeb.Components.UI
  
  # Not currently using NodeManager directly
  # alias XIAM.Hierarchy.NodeManager
  
  def render(assigns) do
    ~H"""
    <div class="hierarchy-tree">
      <div class="mb-4">
        <div class="flex justify-between items-center">
          <h3 class="text-lg font-semibold">Hierarchy Tree</h3>
          <button type="button" phx-click="show_new_node_modal" class="btn btn-primary btn-sm">
            <.icon name="hero-plus-circle" class="mr-1 h-5 w-5" />
            Add Root Node
          </button>
        </div>
        <div class="text-sm text-gray-500 mt-1">
          <%= @loading_count %> nodes total
        </div>
      </div>
      
      <div class="hierarchy-nodes">
        <%= if Enum.empty?(@root_nodes) do %>
          <div class="p-4 text-center text-gray-500 border border-dashed rounded-lg">
            <p>No nodes found. Create your first node to get started.</p>
          </div>
        <% else %>
          <ul class="space-y-2">
            <%= for node <- @root_nodes do %>
              <li>
                <.tree_node 
                  node={node} 
                  expanded_nodes={@expanded_nodes} 
                  selected_node={@selected_node}
                />
              </li>
            <% end %>
          </ul>
        <% end %>
      </div>
    </div>
    """
  end
  
  def tree_node(assigns) do
    ~H"""
    <div class={[
      "flex items-center py-1 px-2 rounded", 
      @selected_node && @selected_node.id == @node.id && "bg-blue-100"
    ]}>
      <div class="flex items-center flex-1">
        <%= if has_children?(@node.id, @expanded_nodes) do %>
          <button type="button" phx-click="toggle_node" phx-value-id={@node.id} class="mr-1">
            <%= if is_expanded?(@node.id, @expanded_nodes) do %>
              <.icon name="hero-chevron-down" class="h-4 w-4 text-gray-500" />
            <% else %>
              <.icon name="hero-chevron-right" class="h-4 w-4 text-gray-500" />
            <% end %>
          </button>
        <% else %>
          <span class="w-4 h-4 mr-1"></span>
        <% end %>
        
        <button type="button" phx-click="select_node" phx-value-id={@node.id} class="flex items-center">
          <.icon 
            name={node_type_icon(@node.node_type)} 
            class="h-4 w-4 mr-1 text-gray-600" 
          />
          <span class="font-medium truncate max-w-xs"><%= @node.name %></span>
          <%= if @node.node_type do %>
            <span class="ml-2 px-1.5 py-0.5 text-xs bg-gray-200 text-gray-700 rounded">
              <%= @node.node_type %>
            </span>
          <% end %>
        </button>
      </div>
      
      <div class="flex ml-2">
        <.dropdown id={"node-actions-#{@node.id}"}>
          <:trigger>
            <button type="button" class="p-1 rounded hover:bg-gray-200">
              <.icon name="hero-ellipsis-vertical" class="h-4 w-4 text-gray-600" />
            </button>
          </:trigger>
          
          <:content>
            <div class="py-1">
              <button type="button" phx-click="show_grant_access_modal" phx-value-id={@node.id} class="w-full text-left px-4 py-2 text-sm hover:bg-gray-100">
                <.icon name="hero-key" class="h-4 w-4 mr-1" />
                Grant Access
              </button>
              
              <button type="button" phx-click="show_new_node_modal" phx-value-parent-id={@node.id} class="w-full text-left px-4 py-2 text-sm hover:bg-gray-100">
                <.icon name="hero-plus-circle" class="h-4 w-4 mr-1" />
                Add Child
              </button>
              
              <button type="button" phx-click="show_edit_node_modal" phx-value-id={@node.id} class="w-full text-left px-4 py-2 text-sm hover:bg-gray-100">
                <.icon name="hero-pencil" class="h-4 w-4 mr-1" />
                Edit
              </button>
              
              <button 
                type="button" 
                phx-click="delete_node" 
                phx-value-id={@node.id}
                data-confirm="Are you sure you want to delete this node and all its children? This action cannot be undone."
                class="w-full text-left px-4 py-2 text-sm hover:bg-gray-100 text-red-600"
              >
                <.icon name="hero-trash" class="h-4 w-4 mr-1 text-red-600" />
                Delete
              </button>
            </div>
          </:content>
        </.dropdown>
      </div>
    </div>
    
    <%= if is_expanded?(@node.id, @expanded_nodes) do %>
      <ul class="pl-6 mt-1 space-y-1">
        <%= for child <- get_children(@node.id, @expanded_nodes) do %>
          <li>
            <.tree_node 
              node={child} 
              expanded_nodes={@expanded_nodes} 
              selected_node={@selected_node}
            />
          </li>
        <% end %>
      </ul>
    <% end %>
    """
  end
  
  # Helper functions
  
  defp is_expanded?(node_id, expanded_nodes) do
    Map.has_key?(expanded_nodes, "#{node_id}")
  end
  
  defp has_children?(node_id, expanded_nodes) do
    case Map.get(expanded_nodes, "#{node_id}") do
      nil -> false  # We don't know yet, assume no children for UI
      children -> length(children) > 0
    end
  end
  
  defp get_children(node_id, expanded_nodes) do
    Map.get(expanded_nodes, "#{node_id}", [])
  end
  
  defp node_type_icon(node_type) do
    case node_type do
      "company" -> "hero-building-office"
      "department" -> "hero-office-building"
      "team" -> "hero-user-group"
      "project" -> "hero-clipboard-document-list"
      "customer" -> "hero-users"
      "location" -> "hero-map-pin"
      "zone" -> "hero-map"
      "element" -> "hero-cube"
      "country" -> "hero-globe-europe-africa"
      _ -> "hero-folder"
    end
  end
end
