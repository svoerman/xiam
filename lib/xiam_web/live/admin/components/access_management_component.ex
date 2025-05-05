defmodule XIAMWeb.Admin.Components.AccessManagementComponent do
  @moduledoc """
  LiveView component for managing access to hierarchy nodes.
  Extracted from the original HierarchyLive module to improve maintainability.
  """
  use XIAMWeb, :live_component
  
  import XIAMWeb.Components.UI.Button
  import XIAMWeb.CoreComponents, except: [button: 1]
  import XIAMWeb.Components.UI
  
  # Remove unused aliases for warnings
  # alias XIAM.Hierarchy.AccessManager
  # alias XIAM.Hierarchy.Access
  
  def render(assigns) do
    ~H"""
    <div class="access-management">
      <div class="mb-4">
        <div class="flex justify-between items-center">
          <h3 class="text-lg font-semibold">Access Management</h3>
          <%= if @selected_node do %>
            <button type="button" phx-click="show_grant_access_modal" phx-value-id={@selected_node.id} class="btn btn-primary btn-sm">
              <.icon name="hero-key" class="mr-1 h-5 w-5" />
              Grant Access
            </button>
          <% end %>
        </div>
      </div>
      
      <%= if @selected_node do %>
        <%= if Enum.empty?(@access_grants) do %>
          <div class="p-4 text-center text-gray-500 border border-dashed rounded-lg">
            <p>No access grants found for this node.</p>
            <p class="text-sm mt-2">
              Users with access to parent nodes will still have access to this node.
            </p>
          </div>
        <% else %>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">User</th>
                  <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Role</th>
                  <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Granted</th>
                  <th scope="col" class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for grant <- @access_grants do %>
                  <tr>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="flex items-center">
                        <div class="flex-shrink-0 h-8 w-8 rounded-full bg-gray-200 flex items-center justify-center">
                          <.icon name="hero-user" class="h-4 w-4 text-gray-600" />
                        </div>
                        <div class="ml-4">
                          <div class="text-sm font-medium text-gray-900">
                            <%= grant.email %>
                          </div>
                        </div>
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">
                        <%= grant.role_name %>
                      </span>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      <%= format_timestamp(grant.inserted_at) %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                      <button 
                        type="button" 
                        phx-click="revoke_access" 
                        phx-value-id={grant.id}
                        class="text-red-600 hover:text-red-900"
                        data-confirm="Are you sure you want to revoke this access grant?"
                      >
                        Revoke
                      </button>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      <% else %>
        <div class="p-4 text-center text-gray-500 border border-dashed rounded-lg">
          <p>Select a node to manage access</p>
        </div>
      <% end %>
    </div>
    """
  end
  
  # Helper functions
  
  defp format_timestamp(nil), do: "Unknown"
  defp format_timestamp(timestamp) do
    Calendar.strftime(timestamp, "%Y-%m-%d %H:%M")
  end
  
  # Client callbacks
  
  def update(%{access_grants: access_grants, selected_node: selected_node} = assigns, socket) do
    {:ok, socket
      |> assign(assigns)
      |> assign(:access_grants, access_grants || [])
      |> assign(:selected_node, selected_node)
    }
  end
  
  # Form for granting access
  
  def access_form(assigns) do
    ~H"""
    <div>
      <.form for={@form} phx-submit="grant_access">
        <div class="space-y-4">
          <div>
            <.input 
              field={@form[:user_id]} 
              label="User" 
              type="select" 
              options={user_options(@users)}
              required
            />
          </div>
          
          <div>
            <.input 
              field={@form[:role_id]} 
              label="Role" 
              type="select" 
              options={role_options(@roles)}
              required
            />
          </div>
          
          <div class="hidden">
            <.input field={@form[:node_id]} type="hidden" value={@selected_node.id} />
          </div>
          
          <div class="pt-4 flex justify-end space-x-3">
            <.button type="button" phx-click="close_modal" variant="secondary">
              Cancel
            </.button>
            <.button type="submit" variant="default">
              Grant Access
            </.button>
          </div>
        </div>
      </.form>
    </div>
    """
  end
  
  defp user_options(users) do
    Enum.map(users, fn user -> {user.id, user.email} end)
  end
  
  defp role_options(roles) do
    Enum.map(roles, fn role -> {role.id, role.name} end)
  end
end
