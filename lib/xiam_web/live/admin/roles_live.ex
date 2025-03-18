defmodule XIAMWeb.Admin.RolesLive do
  use XIAMWeb, :live_view
  
  alias XIAM.RBAC.Role
  alias XIAM.RBAC.Capability
  alias XIAM.Repo
  import Ecto.Query
  
  @impl true
  def mount(_params, _session, socket) do
    roles_query = from r in Role, order_by: r.name, preload: [:capabilities]
    roles = Repo.all(roles_query)
    capabilities = Capability.list_capabilities()
    
    {:ok, assign(socket, 
      page_title: "Manage Roles & Capabilities",
      roles: roles,
      capabilities: capabilities,
      selected_role: nil,
      selected_capability: nil,
      show_role_modal: false,
      show_capability_modal: false,
      form_mode: nil # :new_role, :edit_role, :new_capability, :edit_capability
    )}
  end

  @impl true
  def handle_params(%{"role_id" => role_id}, _uri, socket) do
    case Repo.get(Role, role_id) |> Repo.preload(:capabilities) do
      nil -> {:noreply, socket |> put_flash(:error, "Role not found") |> push_patch(to: ~p"/admin/roles")}
      role -> {:noreply, assign(socket, selected_role: role)}
    end
  end
  
  def handle_params(%{"capability_id" => capability_id}, _uri, socket) do
    case Repo.get(Capability, capability_id) do
      nil -> {:noreply, socket |> put_flash(:error, "Capability not found") |> push_patch(to: ~p"/admin/roles")}
      capability -> {:noreply, assign(socket, selected_capability: capability)}
    end
  end
  
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, selected_role: nil, selected_capability: nil)}
  end

  @impl true
  def handle_event("show_new_role_modal", _params, socket) do
    {:noreply, assign(socket, show_role_modal: true, form_mode: :new_role, selected_role: nil)}
  end
  
  def handle_event("show_edit_role_modal", %{"id" => id}, socket) do
    role = Repo.get(Role, id) |> Repo.preload(:capabilities)
    {:noreply, assign(socket, show_role_modal: true, form_mode: :edit_role, selected_role: role)}
  end
  
  def handle_event("show_new_capability_modal", _params, socket) do
    {:noreply, assign(socket, show_capability_modal: true, form_mode: :new_capability, selected_capability: nil)}
  end
  
  def handle_event("show_edit_capability_modal", %{"id" => id}, socket) do
    capability = Repo.get(Capability, id)
    {:noreply, assign(socket, show_capability_modal: true, form_mode: :edit_capability, selected_capability: capability)}
  end
  
  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, show_role_modal: false, show_capability_modal: false)}
  end
  
  def handle_event("save_role", %{"role" => role_params}, socket) do
    case socket.assigns.form_mode do
      :new_role -> create_role(socket, role_params)
      :edit_role -> update_role(socket, role_params)
      _ -> {:noreply, socket |> put_flash(:error, "Invalid form mode")}
    end
  end
  
  def handle_event("save_capability", %{"capability" => capability_params}, socket) do
    case socket.assigns.form_mode do
      :new_capability -> create_capability(socket, capability_params)
      :edit_capability -> update_capability(socket, capability_params)
      _ -> {:noreply, socket |> put_flash(:error, "Invalid form mode")}
    end
  end
  
  def handle_event("update_role_capabilities", %{"role" => %{"capability_ids" => capability_ids}}, socket) do
    case socket.assigns.selected_role do
      nil -> 
        {:noreply, socket |> put_flash(:error, "No role selected")}
      role ->
        # Parse the capability IDs (Phoenix sends them as a map with string keys)
        capability_ids = capability_ids
                         |> Enum.filter(fn {_k, v} -> v == "true" end)
                         |> Enum.map(fn {k, _v} -> String.to_integer(k) end)
        
        case Role.update_role_capabilities(role, capability_ids) do
          {:ok, updated_role} ->
            roles = refresh_roles(socket)
            
            {:noreply, socket 
              |> assign(roles: roles, selected_role: updated_role, show_role_modal: false)
              |> put_flash(:info, "Role capabilities updated successfully")}
          
          {:error, _changeset} ->
            {:noreply, socket |> put_flash(:error, "Failed to update role capabilities")}
        end
    end
  end
  
  def handle_event("delete_role", %{"id" => id}, socket) do
    role = Repo.get(Role, id)
    
    if role do
      case Repo.delete(role) do
        {:ok, _} ->
          roles = refresh_roles(socket)
          {:noreply, socket 
            |> assign(roles: roles, selected_role: nil)
            |> put_flash(:info, "Role deleted successfully")}
        
        {:error, _changeset} ->
          {:noreply, socket |> put_flash(:error, "Failed to delete role. It may be in use.")}
      end
    else
      {:noreply, socket |> put_flash(:error, "Role not found")}
    end
  end
  
  def handle_event("delete_capability", %{"id" => id}, socket) do
    capability = Repo.get(Capability, id)
    
    if capability do
      case Repo.delete(capability) do
        {:ok, _} ->
          capabilities = Capability.list_capabilities()
          roles = refresh_roles(socket)
          
          {:noreply, socket 
            |> assign(capabilities: capabilities, roles: roles, selected_capability: nil)
            |> put_flash(:info, "Capability deleted successfully")}
        
        {:error, _changeset} ->
          {:noreply, socket |> put_flash(:error, "Failed to delete capability. It may be in use.")}
      end
    else
      {:noreply, socket |> put_flash(:error, "Capability not found")}
    end
  end
  
  # Private helpers
  
  defp create_role(socket, role_params) do
    case Role.create_role(role_params) do
      {:ok, _role} ->
        roles = refresh_roles(socket)
        
        {:noreply, socket 
          |> assign(roles: roles, show_role_modal: false)
          |> put_flash(:info, "Role created successfully")}
      
      {:error, changeset} ->
        {:noreply, socket |> put_flash(:error, "Failed to create role: #{inspect(changeset.errors)}")}
    end
  end
  
  defp update_role(socket, role_params) do
    case socket.assigns.selected_role do
      nil -> 
        {:noreply, socket |> put_flash(:error, "No role selected")}
      role ->
        case Role.update_role(role, role_params) do
          {:ok, updated_role} ->
            roles = refresh_roles(socket)
            
            {:noreply, socket 
              |> assign(roles: roles, selected_role: updated_role, show_role_modal: false)
              |> put_flash(:info, "Role updated successfully")}
          
          {:error, changeset} ->
            {:noreply, socket |> put_flash(:error, "Failed to update role: #{inspect(changeset.errors)}")}
        end
    end
  end
  
  defp create_capability(socket, capability_params) do
    case Capability.create_capability(capability_params) do
      {:ok, _capability} ->
        capabilities = Capability.list_capabilities()
        
        {:noreply, socket 
          |> assign(capabilities: capabilities, show_capability_modal: false)
          |> put_flash(:info, "Capability created successfully")}
      
      {:error, changeset} ->
        {:noreply, socket |> put_flash(:error, "Failed to create capability: #{inspect(changeset.errors)}")}
    end
  end
  
  defp update_capability(socket, capability_params) do
    case socket.assigns.selected_capability do
      nil -> 
        {:noreply, socket |> put_flash(:error, "No capability selected")}
      capability ->
        case Capability.update_capability(capability, capability_params) do
          {:ok, updated_capability} ->
            capabilities = Capability.list_capabilities()
            
            {:noreply, socket 
              |> assign(capabilities: capabilities, selected_capability: updated_capability, show_capability_modal: false)
              |> put_flash(:info, "Capability updated successfully")}
          
          {:error, changeset} ->
            {:noreply, socket |> put_flash(:error, "Failed to update capability: #{inspect(changeset.errors)}")}
        end
    end
  end
  
  defp refresh_roles(_socket) do
    roles_query = from r in Role, order_by: r.name, preload: [:capabilities]
    Repo.all(roles_query)
  end
  

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <.admin_header
        title="Roles & Capabilities Management"
        subtitle="Define roles and capabilities for your RBAC system"
      />

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <!-- Roles Section -->
        <div class="bg-card text-card-foreground rounded-lg shadow-sm border overflow-hidden">
          <div class="px-4 py-5 sm:px-6 bg-muted border-b flex justify-between items-center">
            <h2 class="text-xl font-semibold text-foreground">Roles</h2>
            <button phx-click="show_new_role_modal" class="px-3 py-1.5 inline-flex items-center justify-center rounded-md text-sm font-medium bg-primary text-primary-foreground shadow hover:bg-primary/90 transition-colors">
              Add Role
            </button>
          </div>
          <div class="p-4">
            <div class="divide-y divide-border">
              <%= for role <- @roles do %>
                <div class="py-4 first:pt-0 last:pb-0">
                  <div class="flex justify-between items-center">
                    <div>
                      <h3 class="text-lg font-medium text-foreground"><%= role.name %></h3>
                      <p class="text-sm text-muted-foreground"><%= role.description %></p>
                      <div class="mt-2 flex flex-wrap gap-1">
                        <%= for capability <- role.capabilities do %>
                          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-primary/10 text-primary">
                            <%= capability.name %>
                          </span>
                        <% end %>
                      </div>
                    </div>
                    <div class="flex space-x-2">
                      <button phx-click="show_edit_role_modal" phx-value-id={role.id} class="text-primary hover:text-primary/80 transition-colors">
                        Edit
                      </button>
                      <button phx-click="delete_role" phx-value-id={role.id} class="text-destructive hover:text-destructive/80 transition-colors" data-confirm="Are you sure you want to delete this role?">
                        Delete
                      </button>
                    </div>
                  </div>
                </div>
              <% end %>
              
              <%= if Enum.empty?(@roles) do %>
                <div class="py-4 text-center text-muted-foreground">
                  No roles defined yet. Click "Add Role" to create one.
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Capabilities Section -->
        <div class="bg-card text-card-foreground rounded-lg shadow-sm border overflow-hidden">
          <div class="px-4 py-5 sm:px-6 bg-muted border-b flex justify-between items-center">
            <h2 class="text-xl font-semibold text-foreground">Capabilities</h2>
            <button phx-click="show_new_capability_modal" class="px-3 py-1.5 inline-flex items-center justify-center rounded-md text-sm font-medium bg-primary text-primary-foreground shadow hover:bg-primary/90 transition-colors">
              Add Capability
            </button>
          </div>
          <div class="p-4">
            <div class="divide-y divide-border">
              <%= for capability <- @capabilities do %>
                <div class="py-4 first:pt-0 last:pb-0">
                  <div class="flex justify-between items-center">
                    <div>
                      <h3 class="text-lg font-medium text-foreground"><%= capability.name %></h3>
                      <p class="text-sm text-muted-foreground"><%= capability.description %></p>
                    </div>
                    <div class="flex space-x-2">
                      <button phx-click="show_edit_capability_modal" phx-value-id={capability.id} class="text-primary hover:text-primary/80 transition-colors">
                        Edit
                      </button>
                      <button phx-click="delete_capability" phx-value-id={capability.id} class="text-destructive hover:text-destructive/80 transition-colors" data-confirm="Are you sure you want to delete this capability?">
                        Delete
                      </button>
                    </div>
                  </div>
                </div>
              <% end %>
              
              <%= if Enum.empty?(@capabilities) do %>
                <div class="py-4 text-center text-muted-foreground">
                  No capabilities defined yet. Click "Add Capability" to create one.
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
      
      <!-- Role Modal -->
      <%= if @show_role_modal do %>
        <div class="fixed inset-0 bg-background/80 backdrop-blur-sm flex items-center justify-center z-50">
          <div class="bg-card text-card-foreground rounded-lg shadow-lg max-w-md w-full mx-auto p-6 border">
            <div class="flex justify-between items-center mb-4">
              <h3 class="text-lg font-medium text-foreground">
                <%= if @form_mode == :new_role, do: "Add New Role", else: "Edit Role" %>
              </h3>
              <button phx-click="close_modal" class="text-muted-foreground hover:text-foreground transition-colors">
                <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            
            <.form for={%{}} phx-submit="save_role">
              <div class="mb-4">
                <label for="role_name" class="block text-sm font-medium text-foreground mb-1.5">Role Name</label>
                <input type="text" id="role_name" name="role[name]" required 
                  value={@selected_role && @selected_role.name}
                  class="flex h-9 w-full rounded-md border border-input bg-transparent px-3 py-1 text-sm shadow-sm transition-colors file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-50" />
              </div>
              
              <div class="mb-4">
                <label for="role_description" class="block text-sm font-medium text-foreground mb-1.5">Description</label>
                <textarea id="role_description" name="role[description]" rows="3"
                  class="flex w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-sm placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-50 min-h-[80px]"><%= @selected_role && @selected_role.description %></textarea>
              </div>
              
              <%= if @form_mode == :edit_role do %>
                <div class="mb-4">
                  <h4 class="block text-sm font-medium text-foreground mb-2">Assign Capabilities</h4>
                  
                  <.form for={%{}} phx-submit="update_role_capabilities">
                    <div class="space-y-2 max-h-60 overflow-y-auto p-2 border border-input rounded-md bg-muted/10">
                      <%= for capability <- @capabilities do %>
                        <div class="flex items-center">
                          <input type="checkbox" id={"capability-#{capability.id}"} name={"role[capability_ids][#{capability.id}]"} value="true" 
                            checked={@selected_role && Enum.any?(@selected_role.capabilities, fn c -> c.id == capability.id end)}
                            class="h-4 w-4 rounded border-primary text-primary focus:ring-primary" />
                          <label for={"capability-#{capability.id}"} class="ml-2 text-sm text-foreground">
                            <%= capability.name %>
                            <span class="text-xs text-muted-foreground ml-1"><%= capability.description %></span>
                          </label>
                        </div>
                      <% end %>
                    </div>
                    
                    <div class="flex justify-end mt-4">
                      <button type="submit" class="px-4 py-2 inline-flex items-center justify-center rounded-md text-sm font-medium bg-primary text-primary-foreground shadow hover:bg-primary/90 transition-colors">
                        Update Capabilities
                      </button>
                    </div>
                  </.form>
                </div>
              <% end %>
              
              <div class="flex justify-end mt-6">
                <button type="button" phx-click="close_modal" class="mr-3 px-4 py-2 inline-flex items-center justify-center rounded-md border border-input bg-background text-sm font-medium shadow-sm hover:bg-accent hover:text-accent-foreground transition-colors">
                  Cancel
                </button>
                <button type="submit" class="px-4 py-2 inline-flex items-center justify-center rounded-md text-sm font-medium bg-primary text-primary-foreground shadow hover:bg-primary/90 transition-colors">
                  <%= if @form_mode == :new_role, do: "Create Role", else: "Save Changes" %>
                </button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>
      
      <!-- Capability Modal -->
      <%= if @show_capability_modal do %>
        <div class="fixed inset-0 bg-background/80 backdrop-blur-sm flex items-center justify-center z-50">
          <div class="bg-card text-card-foreground rounded-lg shadow-lg max-w-md w-full mx-auto p-6 border">
            <div class="flex justify-between items-center mb-4">
              <h3 class="text-lg font-medium text-foreground">
                <%= if @form_mode == :new_capability, do: "Add New Capability", else: "Edit Capability" %>
              </h3>
              <button phx-click="close_modal" class="text-muted-foreground hover:text-foreground transition-colors">
                <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            
            <.form for={%{}} phx-submit="save_capability">
              <div class="mb-4">
                <label for="capability_name" class="block text-sm font-medium text-foreground mb-1.5">Capability Name</label>
                <input type="text" id="capability_name" name="capability[name]" required 
                  value={@selected_capability && @selected_capability.name}
                  class="flex h-9 w-full rounded-md border border-input bg-transparent px-3 py-1 text-sm shadow-sm transition-colors file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-50" />
              </div>
              
              <div class="mb-4">
                <label for="capability_description" class="block text-sm font-medium text-foreground mb-1.5">Description</label>
                <textarea id="capability_description" name="capability[description]" rows="3"
                  class="flex w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-sm placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-50 min-h-[80px]"><%= @selected_capability && @selected_capability.description %></textarea>
              </div>
              
              <div class="flex justify-end mt-6">
                <button type="button" phx-click="close_modal" class="mr-3 px-4 py-2 inline-flex items-center justify-center rounded-md border border-input bg-background text-sm font-medium shadow-sm hover:bg-accent hover:text-accent-foreground transition-colors">
                  Cancel
                </button>
                <button type="submit" class="px-4 py-2 inline-flex items-center justify-center rounded-md text-sm font-medium bg-primary text-primary-foreground shadow hover:bg-primary/90 transition-colors">
                  <%= if @form_mode == :new_capability, do: "Create Capability", else: "Save Changes" %>
                </button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
