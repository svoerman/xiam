defmodule XIAMWeb.Admin.ConsentRecordsLive do
  use XIAMWeb, :live_view

  # Import form helpers
  import Phoenix.Component
  import XIAMWeb.Components.UI

  alias XIAM.Consent
  alias XIAM.Users
  alias XIAM.Users.User

  @impl true
  def mount(_params, session, socket) do
    current_user = session["pow_user_id"]
    |> to_int()
    |> case do
      id when is_integer(id) -> XIAM.Users.get_user(id)
      _ -> nil
    end

    {:ok, socket
      |> assign(current_user: current_user)
      |> assign(page_title: "Consent Records")
      |> assign(consent_records: [])
      |> assign(page: 1)
      |> assign(per_page: 25)
      |> assign(total_pages: 1)
      |> assign(total_entries: 0)
      |> assign(filter: %{
        consent_type: nil,
        user_id: nil,
        status: nil,
        date_from: nil,
        date_to: nil
      })
      |> assign(show_detail_modal: false)
      |> assign(selected_record: nil)
      |> assign(theme: "light")
      |> load_consent_records()}
  end

  # Helper to convert values to integer (copied from UsersLive)
  defp to_int(value) when is_integer(value), do: value
  defp to_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {i, ""} -> i
      _ -> nil
    end
  end
  defp to_int(_), do: nil

  @impl true
  def handle_params(params, _url, socket) do
    page = parse_page(params)

    {:noreply, socket
      |> assign(page: page)
      |> load_consent_records()}
  end

  @impl true
  def handle_event("filter", %{"filter" => filter_params}, socket) do
    filter = %{
      consent_type: filter_params["consent_type"],
      user_id: filter_params["user_id"],
      status: filter_params["status"],
      date_from: filter_params["date_from"],
      date_to: filter_params["date_to"]
    }

    {:noreply, socket
      |> assign(filter: filter, page: 1)
      |> load_consent_records()}
  end

  def handle_event("clear_filters", _, socket) do
    filter = %{
      consent_type: nil,
      user_id: nil,
      status: nil,
      date_from: nil,
      date_to: nil
    }

    {:noreply, socket
      |> assign(filter: filter, page: 1)
      |> load_consent_records()}
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/consents?page=#{page}")}
  end

  def handle_event("show_details", %{"id" => id}, socket) do
    consent_record = Consent.get_consent_record!(id)

    {:noreply, socket
      |> assign(selected_record: consent_record)
      |> assign(show_detail_modal: true)}
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, show_detail_modal: false)}
  end

  def handle_event("toggle_theme", _, socket) do
    current_theme = socket.assigns.theme
    new_theme = if current_theme == "light", do: "dark", else: "light"
    {:noreply, assign(socket, theme: new_theme)}
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

  defp load_consent_records(socket) do
    %{page: page, per_page: per_page, filter: filter} = socket.assigns

    # Get pagination params
    pagination = %{page: page, per_page: per_page}

    # Get consent records with pagination and filtering
    %{items: consent_records, total_count: total_entries, total_pages: total_pages} =
      Consent.list_consent_records(filter, pagination)

    socket
    |> assign(consent_records: consent_records)
    |> assign(total_pages: total_pages)
    |> assign(total_entries: total_entries)
  end

  # Get common consent types for filter dropdown
  defp consent_types do
    [
      "marketing_email",
      "terms_of_service",
      "privacy_policy",
      "data_processing",
      "cookie_usage",
      "third_party_sharing",
      "location_tracking",
      "analytics"
    ]
  end

  # Format consent status for display
  defp consent_status(record) do
    cond do
      record.revoked_at -> "Revoked"
      record.consent_given -> "Active"
      true -> "Rejected"
    end
  end

  # Get color for status pill
  defp status_color(record) do
    cond do
      record.revoked_at -> "bg-red-100 dark:bg-red-900/30 text-red-800 dark:text-red-300"
      record.consent_given -> "bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-300"
      true -> "bg-yellow-100 dark:bg-yellow-900/30 text-yellow-800 dark:text-yellow-300"
    end
  end

  # Format datetime for display
  defp format_datetime(nil), do: ""
  
  # Handle DateTime (has timezone)
  defp format_datetime(%DateTime{} = datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")
  end
  
  # Handle NaiveDateTime (no timezone)
  defp format_datetime(%NaiveDateTime{} = datetime) do
    datetime
    |> NaiveDateTime.truncate(:second)
    |> Calendar.strftime("%Y-%m-%d %H:%M:%S")
  end
  
  # Fallback for other types
  defp format_datetime(_), do: ""

  # Format user info
  defp format_user(nil), do: "Unknown"
  defp format_user(user_id) do
    case Users.get_user(user_id) do
      %User{email: email} -> email
      _ -> "User ##{user_id}"
    end
  end

  # Format consent type for display
  defp format_consent_type(type) do
    type
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["min-h-screen", @theme]} phx-hook="Theme" id="theme-container">
    <div class="container mx-auto px-4 py-8 bg-background text-foreground">
      <.admin_header
        title="Consent Records"
        subtitle="Manage and track user consent for GDPR compliance"
      />

      <!-- Filters -->
      <div class="bg-card text-card-foreground rounded-lg shadow-sm border overflow-hidden mb-8">
        <div class="px-4 py-3 border-b bg-muted">
          <h3 class="font-medium text-foreground">Filter Consent Records</h3>
        </div>
        <div class="p-4">
          <form phx-submit="filter">
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
              <div>
                <label class="block text-sm font-medium text-foreground mb-1.5">Consent Type</label>
                <select name="filter[consent_type]" class="flex h-9 w-full rounded-md border border-input bg-transparent px-3 py-1 text-sm shadow-sm transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring">
                  <option value="">All Types</option>
                  <%= for type <- consent_types() do %>
                    <option value={type} selected={type == @filter.consent_type}><%= format_consent_type(type) %></option>
                  <% end %>
                </select>
              </div>

              <div>
                <label class="block text-sm font-medium text-foreground mb-1.5">Status</label>
                <select name="filter[status]" class="flex h-9 w-full rounded-md border border-input bg-transparent px-3 py-1 text-sm shadow-sm transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring">
                  <option value="">All Statuses</option>
                  <option value="active" selected={@filter.status == "active"}>Active</option>
                  <option value="revoked" selected={@filter.status == "revoked"}>Revoked</option>
                  <option value="rejected" selected={@filter.status == "rejected"}>Rejected</option>
                </select>
              </div>

              <div>
                <label class="block text-sm font-medium text-foreground mb-1.5">User ID</label>
                <input type="text" name="filter[user_id]" value={@filter.user_id} placeholder="User ID or Email"
                  class="flex h-9 w-full rounded-md border border-input bg-transparent px-3 py-1 text-sm shadow-sm transition-colors placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring" />
              </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
              <div>
                <label class="block text-sm font-medium text-foreground mb-1.5">From Date</label>
                <input type="date" name="filter[date_from]" value={@filter.date_from}
                  class="flex h-9 w-full rounded-md border border-input bg-transparent px-3 py-1 text-sm shadow-sm transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring" />
              </div>

              <div>
                <label class="block text-sm font-medium text-foreground mb-1.5">To Date</label>
                <input type="date" name="filter[date_to]" value={@filter.date_to}
                  class="flex h-9 w-full rounded-md border border-input bg-transparent px-3 py-1 text-sm shadow-sm transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring" />
              </div>
            </div>

            <div class="flex justify-end space-x-3">
              <button type="button" phx-click="clear_filters" class="px-4 py-2 inline-flex items-center justify-center rounded-md border border-input bg-background text-sm font-medium shadow-sm hover:bg-accent hover:text-accent-foreground transition-colors">
                Clear Filters
              </button>
              <button type="submit" class="px-4 py-2 inline-flex items-center justify-center rounded-md text-sm font-medium bg-primary text-primary-foreground shadow hover:bg-primary/90 transition-colors">
                Apply Filters
              </button>
            </div>
          </form>
        </div>
      </div>

      <!-- Consent Records Table -->
      <div class="bg-card text-card-foreground rounded-lg shadow-sm border overflow-hidden">
        <div class="border-b p-4 bg-muted flex items-center justify-between">
          <h3 class="text-lg font-medium text-foreground">
            Consent Records <span class="text-sm text-muted-foreground">(<%= @total_entries %> total)</span>
          </h3>
        </div>

        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-border">
            <thead class="bg-muted/50">
              <tr>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                  ID
                </th>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                  User
                </th>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                  Consent Type
                </th>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                  Status
                </th>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                  Date Created
                </th>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                  Last Modified
                </th>
                <th scope="col" class="px-6 py-3 text-right text-xs font-medium text-muted-foreground uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-border">
              <%= for record <- @consent_records do %>
                <tr class="hover:bg-muted/50 transition-colors">
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-foreground">
                    <%= record.id %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-muted-foreground">
                    <%= format_user(record.user_id) %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-muted-foreground">
                    <%= format_consent_type(record.consent_type) %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class={["px-2 inline-flex text-xs leading-5 font-semibold rounded-full", status_color(record)]}>
                      <%= consent_status(record) %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-muted-foreground">
                    <%= format_datetime(record.inserted_at) %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-muted-foreground">
                    <%= format_datetime(record.updated_at) %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                    <button phx-click="show_details" phx-value-id={record.id} class="text-primary hover:text-primary/80 transition-colors">
                      View Details
                    </button>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <!-- Empty State -->
        <%= if @consent_records == [] do %>
          <div class="text-center py-12">
            <svg xmlns="http://www.w3.org/2000/svg" class="mx-auto h-12 w-12 text-muted-foreground" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-foreground">No consent records found</h3>
            <p class="mt-1 text-sm text-muted-foreground">
              Try adjusting your filters or check back later.
            </p>
          </div>
        <% end %>

        <!-- Pagination -->
        <%= if @total_pages > 1 do %>
          <div class="border-t border-border px-4 py-3 flex items-center justify-between">
            <div>
              <p class="text-sm text-muted-foreground">
                Showing <%= (@page - 1) * @per_page + 1 %> to <%= min(@page * @per_page, @total_entries) %> of <%= @total_entries %> results
              </p>
            </div>
            <nav class="relative z-0 inline-flex shadow-sm -space-x-px" aria-label="Pagination">
              <!-- Previous Page -->
              <button phx-click="change_page" phx-value-page={@page - 1} disabled={@page == 1}
                class={["relative inline-flex items-center px-2 py-2 rounded-l-md border border-input text-sm font-medium transition-colors", if(@page == 1, do: "text-muted-foreground/40 cursor-not-allowed", else: "text-foreground hover:bg-accent")]}>
                <span class="sr-only">Previous</span>
                <svg class="h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                  <path fill-rule="evenodd" d="M12.707 5.293a1 1 0 010 1.414L9.414 10l3.293 3.293a1 1 0 01-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z" clip-rule="evenodd" />
                </svg>
              </button>

              <!-- Page Numbers -->
              <%= for page_num <- max(1, @page - 2)..min(@total_pages, @page + 2) do %>
                <button phx-click="change_page" phx-value-page={page_num}
                  class={["relative inline-flex items-center px-4 py-2 border border-input text-sm font-medium transition-colors", if(page_num == @page, do: "bg-primary/10 text-primary z-10", else: "bg-background text-foreground hover:bg-accent")]}>
                  <%= page_num %>
                </button>
              <% end %>

              <!-- Next Page -->
              <button phx-click="change_page" phx-value-page={@page + 1} disabled={@page >= @total_pages}
                class={["relative inline-flex items-center px-2 py-2 rounded-r-md border border-input text-sm font-medium transition-colors", if(@page >= @total_pages, do: "text-muted-foreground/40 cursor-not-allowed", else: "text-foreground hover:bg-accent")]}>
                <span class="sr-only">Next</span>
                <svg class="h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                  <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd" />
                </svg>
              </button>
            </nav>
          </div>
        <% end %>
      </div>

      <%= if @show_detail_modal do %>
        <div class="fixed inset-0 bg-background/80 backdrop-blur-sm flex items-center justify-center z-50">
          <div class="bg-card text-card-foreground rounded-lg shadow-lg overflow-hidden w-full max-w-lg border border-border">
            <div class="bg-muted/50 px-4 py-3 border-b border-border">
              <div class="flex justify-between items-center">
                <h3 class="text-lg font-medium text-foreground">Consent Record Details</h3>
                <button phx-click="close_modal" class="text-muted-foreground hover:text-foreground transition-colors">
                  <span class="sr-only">Close</span>
                  <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>
            </div>

            <div class="p-4">
              <div class="mb-4">
                <div class="text-sm font-medium text-muted-foreground mb-1">ID</div>
                <div class="text-foreground"><%= @selected_record.id %></div>
              </div>

              <div class="mb-4">
                <div class="text-sm font-medium text-muted-foreground mb-1">User</div>
                <div class="text-foreground"><%= format_user(@selected_record.user_id) %></div>
              </div>

              <div class="mb-4">
                <div class="text-sm font-medium text-muted-foreground mb-1">Consent Type</div>
                <div class="text-foreground"><%= format_consent_type(@selected_record.consent_type) %></div>
              </div>

              <div class="mb-4">
                <div class="text-sm font-medium text-muted-foreground mb-1">Status</div>
                <div>
                  <span class={["px-2 py-1 text-xs rounded-full", status_color(@selected_record)]}>
                    <%= consent_status(@selected_record) %>
                  </span>
                </div>
              </div>

              <div class="mb-4">
                <div class="text-sm font-medium text-muted-foreground mb-1">Created At</div>
                <div class="text-foreground"><%= format_datetime(@selected_record.inserted_at) %></div>
              </div>

              <div class="mb-4">
                <div class="text-sm font-medium text-muted-foreground mb-1">Last Modified</div>
                <div class="text-foreground"><%= format_datetime(@selected_record.updated_at) %></div>
              </div>

              <%= if @selected_record.revoked_at do %>
                <div class="mb-4">
                  <div class="text-sm font-medium text-muted-foreground mb-1">Revoked At</div>
                  <div class="text-foreground"><%= format_datetime(@selected_record.revoked_at) %></div>
                </div>
              <% end %>

              <div class="mb-4">
                <div class="text-sm font-medium text-muted-foreground mb-1">IP Address</div>
                <div class="text-foreground"><%= @selected_record.ip_address %></div>
              </div>

              <div class="mb-4">
                <div class="text-sm font-medium text-muted-foreground mb-1">User Agent</div>
                <div class="break-words text-foreground"><%= @selected_record.user_agent || "N/A" %></div>
              </div>

              <div class="mb-4">
                <div class="text-sm font-medium text-muted-foreground mb-1">Consent Details</div>
                <div class="break-words text-foreground">
                  <strong>Type:</strong> <%= @selected_record.consent_type %><br>
                  <strong>Status:</strong> <%= if @selected_record.consent_given, do: "Granted", else: "Denied" %>
                </div>
              </div>
            </div>

            <div class="bg-muted/50 px-4 py-3 border-t border-border flex justify-end">
              <button phx-click="close_modal" class="px-3 py-2 inline-flex items-center justify-center rounded-md bg-background text-foreground border border-input shadow-sm hover:bg-accent transition-colors text-sm">Close</button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    </div>
    """
  end
end
