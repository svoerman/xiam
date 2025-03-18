defmodule XIAMWeb.Admin.AuditLogsLive do
  use XIAMWeb, :live_view
  
  alias XIAM.Repo
  alias XIAM.Audit
  alias XIAM.Audit.AuditLog
  alias XIAM.Users.User
  import XIAMWeb.CoreComponents
  
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    theme = if connected?(socket), do: get_connect_params(socket)["theme"], else: "light"
    
    {:ok, socket
      |> assign(page_title: "Audit Logs")
      |> assign(theme: theme || "light")
      |> assign(audit_logs: [])
      |> assign(page: 1)
      |> assign(per_page: 25)
      |> assign(total_pages: 1)
      |> assign(total_entries: 0)
      |> assign(filter: %{
        action: nil,
        user_id: nil,
        date_from: nil,
        date_to: nil,
        search: nil
      })
      |> load_audit_logs()}
  end
  
  @impl true
  def handle_params(params, _url, socket) do
    page = parse_page(params)
    
    {:noreply, socket 
      |> assign(page: page)
      |> load_audit_logs()}
  end
  
  @impl true
  def handle_event("filter", %{"filter" => filter_params}, socket) do
    filter = %{
      action: filter_params["action"],
      user_id: filter_params["user_id"],
      date_from: filter_params["date_from"],
      date_to: filter_params["date_to"],
      search: filter_params["search"]
    }
    
    {:noreply, socket
      |> assign(filter: filter, page: 1)
      |> load_audit_logs()}
  end
  
  def handle_event("clear_filters", _, socket) do
    filter = %{
      action: nil,
      user_id: nil,
      date_from: nil,
      date_to: nil,
      search: nil
    }
    
    {:noreply, socket
      |> assign(filter: filter, page: 1)
      |> load_audit_logs()}
  end
  
  def handle_event("change_page", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/audit-logs?page=#{page}")}
  end
  
  defp parse_page(params) do
    case params do
      %{"page" => page} ->
        case Integer.parse(page) do
          {page_num, _} when page_num > 0 -> page_num
          _ -> 1
        end
      _ -> 1
    end
  end
  
  defp load_audit_logs(socket) do
    %{page: page, per_page: per_page, filter: filter} = socket.assigns
    
    # Use the Audit context to fetch logs
    pagination = %{page: page, per_page: per_page}
    
    # Get audit logs with pagination and filtering
    %{entries: audit_logs, total_entries: total_entries, total_pages: total_pages} = 
      Audit.list_audit_logs(filter, pagination)
    
    socket
    |> assign(audit_logs: audit_logs)
    |> assign(total_pages: total_pages)
    |> assign(total_entries: total_entries)
  end
  
  # We've moved filter implementation to the Audit context
  
  # Get common action types for filter dropdown
  defp common_actions do
    [
      "login_success",
      "login_failure",
      "password_reset",
      "mfa_enabled",
      "mfa_disabled",
      "user_created",
      "user_updated",
      "user_deleted",
      "api_login_success",
      "api_login_failure",
      "gdpr_data_export",
      "gdpr_data_deletion",
      "update_setting",
      "consent_created",
      "consent_updated",
      "consent_revoked",
      "role_created",
      "role_updated",
      "role_deleted"
    ]
  end
  
  # Get available users for filter dropdown
  defp available_users do
    # In a real app, you might want to limit this or load asynchronously
    # Here we're just getting users who have audit log entries
    query = from log in AuditLog,
            join: user in User, on: log.user_id == user.id,
            select: {user.email, user.id},
            distinct: user.id,
            order_by: user.email,
            limit: 100
            
    Repo.all(query)
  end
  
  # Format metadata for display
  defp format_metadata(metadata) when is_map(metadata) do
    metadata
    |> Enum.map(fn {k, v} -> "#{k}: #{inspect(v)}" end)
    |> Enum.join(", ")
  end
  
  defp format_metadata(_), do: ""
  
  # Format datetime for display
  defp format_datetime(datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> Calendar.strftime("%Y-%m-%d %H:%M:%S")
  end

  @impl true
  def handle_event("toggle_theme", _, socket) do
    new_theme = if socket.assigns.theme == "light", do: "dark", else: "light"
    {:noreply, assign(socket, theme: new_theme)}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class={["min-h-screen", @theme]} phx-hook="Theme" id="theme-container">
    <div class="container mx-auto px-4 py-8 bg-background text-foreground">
      <div class="flex justify-between items-center mb-8">
        <div>
          <h1 class="text-3xl font-bold text-foreground">Audit Logs</h1>
          <div class="text-sm text-muted-foreground">
            View and search system audit logs for security and compliance
          </div>
        </div>
        <div class="flex items-center space-x-4">
          <.link patch={~p"/admin"} class="text-primary hover:text-primary/80 transition-colors">
            ← Back to Dashboard
          </.link>
          <div class="theme-toggle">
            <button
              id="theme-toggle-btn"
              phx-click="toggle_theme"
              class="rounded-full p-2 bg-muted hover:bg-muted/80 transition-colors"
              aria-label="Toggle theme"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class={["h-5 w-5 transition-transform", @theme == "dark" && "rotate-180"]} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z" />
              </svg>
            </button>
          </div>
        </div>
      </div>
      
      <!-- Filter Form -->
      <div class="bg-card text-card-foreground rounded-lg shadow-sm border border-border overflow-hidden mb-8">
        <div class="border-b border-border p-4 bg-muted/50">
          <h3 class="text-lg font-medium text-foreground">Filters</h3>
        </div>
        
        <div class="p-6">
          <.form for={%{}} phx-submit="filter">
            <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
              <div>
                <label class="block text-sm font-medium text-foreground mb-1">Action Type</label>
                <select name="filter[action]" class="block w-full p-2 bg-background border border-input rounded-md shadow-sm text-foreground focus:ring-2 focus:ring-primary/25 focus:border-primary">
                  <option value="">All Actions</option>
                  <%= for action <- common_actions() do %>
                    <option value={action} selected={@filter.action == action}>
                      <%= action |> String.replace("_", " ") |> String.capitalize() %>
                    </option>
                  <% end %>
                </select>
              </div>
              
              <div>
                <label class="block text-sm font-medium text-foreground mb-1">User</label>
                <select name="filter[user_id]" class="block w-full p-2 bg-background border border-input rounded-md shadow-sm text-foreground focus:ring-2 focus:ring-primary/25 focus:border-primary">
                  <option value="">All Users</option>
                  <%= for {email, id} <- available_users() do %>
                    <option value={id} selected={@filter.user_id == "#{id}"}>
                      <%= email %>
                    </option>
                  <% end %>
                </select>
              </div>
              
              <div>
                <label class="block text-sm font-medium text-foreground mb-1">From Date</label>
                <input type="date" name="filter[date_from]" value={@filter.date_from}
                  class="block w-full p-2 bg-background border border-input rounded-md shadow-sm text-foreground focus:ring-2 focus:ring-primary/25 focus:border-primary" />
              </div>
              
              <div>
                <label class="block text-sm font-medium text-foreground mb-1">To Date</label>
                <input type="date" name="filter[date_to]" value={@filter.date_to}
                  class="block w-full p-2 bg-background border border-input rounded-md shadow-sm text-foreground focus:ring-2 focus:ring-primary/25 focus:border-primary" />
              </div>
            </div>
            
            <div class="flex items-center mb-4">
              <div class="flex-grow">
                <input type="text" name="filter[search]" placeholder="Search by action, user, or metadata..." value={@filter.search}
                  class="block w-full p-2 bg-background border border-input rounded-md shadow-sm text-foreground focus:ring-2 focus:ring-primary/25 focus:border-primary" />
              </div>
              <div class="ml-4 flex">
                <button type="submit" class="px-4 py-2 bg-primary text-primary-foreground rounded-md hover:bg-primary/90 transition-colors">
                  Apply Filters
                </button>
                <button type="button" phx-click="clear_filters" class="ml-2 px-4 py-2 border border-input bg-background text-foreground rounded-md hover:bg-accent transition-colors">
                  Clear
                </button>
              </div>
            </div>
          </.form>
        </div>
      </div>
      
      <!-- Results -->
      <div class="bg-card text-card-foreground rounded-lg shadow-sm border border-border overflow-hidden">
        <div class="border-b border-border p-4 bg-muted/50 flex items-center justify-between">
          <h3 class="text-lg font-medium text-foreground">
            Audit Log Entries <span class="text-sm text-muted-foreground">(<%= @total_entries %> total)</span>
          </h3>
          
          <div class="text-sm text-muted-foreground">
            <span>Page <%= @page %> of <%= @total_pages %></span>
          </div>
        </div>
        
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-border">
            <thead class="bg-muted/50">
              <tr>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                  Time
                </th>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                  Action
                </th>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                  User
                </th>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                  IP Address
                </th>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                  Details
                </th>
              </tr>
            </thead>
            <tbody class="bg-background divide-y divide-border">
              <%= for log <- @audit_logs do %>
                <tr>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-muted-foreground">
                    <%= format_datetime(log.inserted_at) %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class={"px-2 py-1 inline-flex text-xs leading-5 font-semibold rounded-full #{action_color(log.action)}"}>
                      <%= log.action |> String.replace("_", " ") %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-foreground">
                    <%= if log.user_email, do: log.user_email, else: "System" %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-muted-foreground">
                    <%= log.ip_address || "-" %>
                  </td>
                  <td class="px-6 py-4 text-sm text-muted-foreground max-w-md truncate">
                    <%= format_metadata(log.metadata) %>
                  </td>
                </tr>
              <% end %>
              
              <%= if Enum.empty?(@audit_logs) do %>
                <tr>
                  <td colspan="5" class="px-6 py-10 text-center text-sm text-muted-foreground">
                    No audit logs found matching your criteria
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
        
        <!-- Pagination -->
        <%= if @total_pages > 1 do %>
          <div class="border-t border-border px-4 py-3 flex items-center justify-between">
            <div>
              <p class="text-sm text-muted-foreground">
                Showing <%= (@page - 1) * @per_page + 1 %> to <%= min(@page * @per_page, @total_entries) %> of <%= @total_entries %> results
              </p>
            </div>
            <nav class="inline-flex rounded-md shadow-sm -space-x-px" aria-label="Pagination">
              <%= if @page > 1 do %>
                <button phx-click="change_page" phx-value-page={@page - 1} class="relative inline-flex items-center px-2 py-2 rounded-l-md border border-input bg-background text-sm font-medium text-foreground hover:bg-accent transition-colors">
                  <span class="sr-only">Previous</span>
                  <svg class="h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                    <path fill-rule="evenodd" d="M12.707 5.293a1 1 0 010 1.414L9.414 10l3.293 3.293a1 1 0 01-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z" clip-rule="evenodd" />
                  </svg>
                </button>
              <% end %>
              
              <%= for page_num <- max(1, @page - 2)..min(@total_pages, @page + 2) do %>
                <button phx-click="change_page" phx-value-page={page_num}
                  class={["relative inline-flex items-center px-4 py-2 border border-input text-sm font-medium transition-colors", if(@page == page_num, do: "bg-primary/10 text-primary z-10", else: "bg-background text-foreground hover:bg-accent")]}>
                  <%= page_num %>
                </button>
              <% end %>
              
              <%= if @page < @total_pages do %>
                <button phx-click="change_page" phx-value-page={@page + 1} class="relative inline-flex items-center px-2 py-2 rounded-r-md border border-input bg-background text-sm font-medium text-foreground hover:bg-accent transition-colors">
                  <span class="sr-only">Next</span>
                  <svg class="h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                    <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd" />
                  </svg>
                </button>
              <% end %>
            </nav>
          </div>
        <% end %>
      </div>
      
      <!-- Export Section -->
      <div class="mt-8 p-4 border border-border rounded-md bg-muted/50">
        <div class="flex items-center justify-between">
          <div>
            <h3 class="font-medium text-foreground">Export Audit Logs</h3>
            <p class="text-sm text-muted-foreground">Download audit logs for compliance and record-keeping</p>
          </div>
          <div class="flex space-x-2">
            <button class="px-4 py-2 bg-background border border-input rounded-md text-foreground hover:bg-accent transition-colors">
              Export CSV
            </button>
            <button class="px-4 py-2 bg-background border border-input rounded-md text-foreground hover:bg-accent transition-colors">
              Export JSON
            </button>
          </div>
        </div>
      </div>
    </div>
    </div>
    """
  end
  
  # Helper function to determine color based on action
  defp action_color(action) do
    cond do
      String.contains?(action, "failure") or String.contains?(action, "deleted") ->
        "bg-red-100 dark:bg-red-900/30 text-red-800 dark:text-red-300"
        
      String.contains?(action, "success") or String.contains?(action, "created") ->
        "bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-300"
        
      String.contains?(action, "updated") or String.contains?(action, "enabled") ->
        "bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-300"
        
      String.contains?(action, "login") ->
        "bg-purple-100 dark:bg-purple-900/30 text-purple-800 dark:text-purple-300"
        
      String.contains?(action, "gdpr") ->
        "bg-yellow-100 dark:bg-yellow-900/30 text-yellow-800 dark:text-yellow-300"
        
      true ->
        "bg-gray-100 dark:bg-gray-800/40 text-gray-800 dark:text-gray-300"
    end
  end
end
