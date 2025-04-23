defmodule XIAMWeb.Admin.GDPRLive do
  use XIAMWeb, :live_view

  alias XIAM.Users.User
  alias XIAM.Consent
  alias XIAM.GDPR.DataPortability
  alias XIAM.GDPR.DataRemoval
  alias XIAM.Repo
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    theme = if connected?(socket), do: get_connect_params(socket)["theme"], else: "light"

    users_query = from u in User,
                  order_by: [desc: u.inserted_at]

    users = Repo.all(users_query)
    consent_types = Consent.list_consent_types()

    socket = socket
    |> assign(:page_title, "GDPR Management")
    |> assign(:theme, theme || "light")
    |> assign(:users, users)
    |> assign(:consent_types, consent_types)
    |> assign(:selected_user, nil)
    |> assign(:show_export_modal, false)
    |> assign(:show_consent_modal, false)
    |> assign(:show_anonymize_modal, false)
    |> assign(:show_delete_modal, false)
    |> assign(:exported_data, nil)
    |> push_event("init-user-select", %{})

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"user_id" => user_id}, _uri, socket) do
    # Convert user_id to integer and fetch user
    user = case Integer.parse(user_id) do
      {id, ""} -> Repo.get_by(User, id: id)
      _ -> nil
    end

    if user do
      consents = Consent.get_user_consents(user.id)
      {:noreply, assign(socket, selected_user: user, user_consents: consents)}
    else
      {:noreply, socket |> put_flash(:error, "User not found") |> push_patch(to: ~p"/admin/gdpr")}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, selected_user: nil, user_consents: nil)}
  end

  @impl true
  def handle_event("select_user", %{"id" => user_id}, socket) do
    if user_id == "" do
      {:noreply, push_patch(socket, to: ~p"/admin/gdpr")}
    else
      {:noreply, push_patch(socket, to: ~p"/admin/gdpr?user_id=#{user_id}")}
    end
  end

  def handle_event("show_export_modal", _, socket) do
    {:noreply, assign(socket, show_export_modal: true)}
  end

  def handle_event("show_consent_modal", _, socket) do
    {:noreply, assign(socket, show_consent_modal: true)}
  end

  def handle_event("show_anonymize_modal", _, socket) do
    {:noreply, assign(socket, show_anonymize_modal: true)}
  end

  def handle_event("show_delete_modal", _, socket) do
    {:noreply, assign(socket, show_delete_modal: true)}
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket,
      show_export_modal: false,
      show_consent_modal: false,
      show_anonymize_modal: false,
      show_delete_modal: false
    )}
  end

  def handle_event("toggle_theme", _, socket) do
    new_theme = if socket.assigns.theme == "light", do: "dark", else: "light"
    {:noreply, assign(socket, theme: new_theme)}
  end

  def handle_event("validate_consent", _params, socket) do
    # Just return the socket unchanged since we don't need validation logic
    {:noreply, socket}
  end

  def handle_event("export_user_data", _, socket) do
    user = socket.assigns.selected_user

    # DataPortability.export_user_data returns a map directly, not a tuple
    try do
      data = DataPortability.export_user_data(user.id)
      {:noreply, assign(socket, exported_data: Jason.encode!(data, pretty: true))}
    rescue
      e ->
        {:noreply, socket |> put_flash(:error, "Failed to export user data: #{inspect(e)}")}
    end
  end

  def handle_event("save_consent", %{"consent" => consent_params}, socket) do
    user = socket.assigns.selected_user

    # Process consent status (convert from string to boolean)
    status = case consent_params["consent_given"] do
      "true" -> true
      "false" -> false
      _ -> false
    end

    consent_params = Map.put(consent_params, "consent_given", status)

    # Create or update consent record directly
    consent_type = consent_params["consent_type"] || consent_params[:consent_type]
    consent_given = consent_params["consent_given"] || consent_params[:consent_given]

    case Consent.record_consent(user.id, consent_type, consent_given) do
      {:ok, _consent} ->
        consents = Consent.get_user_consents(user.id)

        {:noreply, socket
          |> assign(user_consents: consents, show_consent_modal: false)
          |> put_flash(:info, "Consent record updated successfully")}

      {:error, _changeset} ->
        {:noreply, socket |> put_flash(:error, "Failed to update consent record")}
    end
  end

  def handle_event("anonymize_user", _, socket) do
    user = socket.assigns.selected_user

    case DataRemoval.anonymize_user(user.id) do
      {:ok, _anonymized_user} ->
        # Refresh user list after anonymization
        users_query = from u in User, order_by: [desc: u.inserted_at]
        users = Repo.all(users_query)

        {:noreply, socket
          |> assign(users: users, selected_user: nil, show_anonymize_modal: false)
          |> put_flash(:info, "User data has been anonymized successfully")
          |> push_patch(to: ~p"/admin/gdpr")}

      {:error, reason} ->
        {:noreply, socket
          |> assign(show_anonymize_modal: false)
          |> put_flash(:error, "Failed to anonymize user data: #{inspect(reason)}")}
    end
  end

  def handle_event("delete_user", _, socket) do
    user = socket.assigns.selected_user

    case DataRemoval.delete_user(user.id) do
      {:ok, _user_id} ->
        # Refresh user list after deletion
        users_query = from u in User, order_by: [desc: u.inserted_at]
        users = Repo.all(users_query)

        {:noreply, socket
          |> assign(users: users, selected_user: nil, show_delete_modal: false)
          |> put_flash(:info, "User has been completely deleted")
          |> push_patch(to: ~p"/admin/gdpr")}

      {:error, reason} ->
        {:noreply, socket
          |> assign(show_delete_modal: false)
          |> put_flash(:error, "Failed to delete user: #{inspect(reason)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="gdpr-container" class="container mx-auto px-4 py-8 bg-background text-foreground">
      <.admin_header
        title="GDPR Compliance Management"
        subtitle="Manage user consent, data portability, and the right to be forgotten"
      />

      <div id="gdpr-grid" class="grid grid-cols-1 md:grid-cols-4 gap-6">
      <!-- User Selection Panel -->
      <div id="user-selection-panel" class="md:col-span-1 bg-card rounded-lg shadow-sm border border-border overflow-hidden">
        <div class="px-4 py-5 bg-muted/50 border-b border-border">
          <h2 class="text-lg font-semibold">Select User</h2>
        </div>
        <div class="p-4">
          <label for="user_select" class="block text-sm font-medium text-muted-foreground mb-1">Select a user:</label>
          <form phx-change="select_user">
            <select
              id="user_select"
              name="id"
              phx-hook="PersistUserSelect"
              class="flex h-10 w-full items-center justify-between rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
            >
              <option value="">Choose a user</option>
              <%= for user <- @users do %>
                <option
                  value={user.id}
                  selected={@selected_user && @selected_user.id == user.id}>
                  <%= user.email %>
                </option>
              <% end %>
            </select>
          </form>
        </div>
      </div>

      <!-- User GDPR Panel -->
      <div id="user-gdpr-panel" class="md:col-span-3 bg-card rounded-lg shadow-sm border border-border overflow-hidden">
        <%= if @selected_user do %>
          <div class="px-4 py-5 bg-muted/50 border-b border-border flex justify-between items-center">
            <h2 class="text-lg font-semibold">GDPR Management: <%= @selected_user.email %></h2>
          </div>
          <div class="p-6">
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-6">
              <!-- Data Portability Card -->
              <div class="border border-border rounded-lg p-4 bg-card shadow-sm">
                <h3 class="text-lg font-medium mb-2">Data Portability</h3>
                <p class="text-sm text-muted-foreground mb-4">
                  Export all user data in a portable format as required by GDPR.
                </p>
                <button phx-click="show_export_modal" class="w-full inline-flex items-center justify-center rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 bg-primary text-primary-foreground hover:bg-primary/90 h-10 px-4">
                  Export User Data
                </button>
              </div>

              <!-- Consent Management Card -->
              <div class="border border-border rounded-lg p-4 bg-card shadow-sm">
                <h3 class="text-lg font-medium mb-2">Consent Management</h3>
                <p class="text-sm text-muted-foreground mb-4">
                  Manage user consent records for different data processing activities.
                </p>
                <button phx-click="show_consent_modal" class="w-full inline-flex items-center justify-center rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 bg-primary text-primary-foreground hover:bg-primary/90 h-10 px-4">
                  Manage Consent
                </button>
              </div>

              <!-- Right to be Forgotten Cards -->
              <div class="border border-border rounded-lg p-4 bg-card shadow-sm">
                <h3 class="text-lg font-medium mb-2">Anonymize User</h3>
                <p class="text-sm text-muted-foreground mb-4">
                  Anonymize user's personal data while keeping system records intact.
                </p>
                <button phx-click="show_anonymize_modal" class="w-full inline-flex items-center justify-center rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 bg-warning text-warning-foreground hover:bg-warning/90 h-10 px-4">
                  Anonymize User Data
                </button>
              </div>

              <div class="border border-border rounded-lg p-4 bg-card shadow-sm">
                <h3 class="text-lg font-medium mb-2">Delete User</h3>
                <p class="text-sm text-muted-foreground mb-4">
                  Completely delete user and all associated data from the system.
                </p>
                <button phx-click="show_delete_modal" class="w-full inline-flex items-center justify-center rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 bg-destructive text-destructive-foreground hover:bg-destructive/90 h-10 px-4">
                  Delete User Completely
                </button>
              </div>
            </div>

            <!-- Current Consent Status -->
            <%= if @user_consents && @user_consents != [] do %>
              <div class="mt-8">
                <h3 class="text-lg font-medium mb-4">Current Consent Status</h3>
                <div class="bg-muted/50 rounded-md p-4">
                  <div class="overflow-x-auto">
                    <table class="w-full border-collapse">
                      <thead>
                        <tr class="border-b border-border">
                          <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">Consent Type</th>
                          <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">Status</th>
                          <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">Last Updated</th>
                        </tr>
                      </thead>
                      <tbody class="divide-y divide-border">
                        <%= for consent <- @user_consents do %>
                          <tr class="hover:bg-muted/50">
                            <td class="px-6 py-4 whitespace-nowrap text-sm"><%= consent.consent_type %></td>
                            <td class="px-6 py-4 whitespace-nowrap">
                              <span class={["px-2 inline-flex text-xs leading-5 font-semibold rounded-full", (if consent.consent_given, do: "bg-success/20 text-success", else: "bg-destructive/20 text-destructive")]}>
                                <%= if consent.consent_given, do: "Granted", else: "Denied" %>
                              </span>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-muted-foreground">
                              <%= Calendar.strftime(consent.updated_at, "%Y-%m-%d %H:%M") %>
                            </td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="p-8 text-center text-muted-foreground">
            Select a user from the list to manage their GDPR-related data.
          </div>
        <% end %>
      </div>
      </div>
    </div>

    <%= if @show_export_modal || @show_consent_modal || @show_anonymize_modal || @show_delete_modal do %>
      <div id="modal-container" class="modal-container">
        <!-- Export Data Modal -->
        <%= if @show_export_modal do %>
          <div class="fixed inset-0 bg-background/80 backdrop-blur-sm flex items-center justify-center z-50">
            <div class="absolute inset-0" phx-click="close_modal"></div>
            <div class="bg-card rounded-lg shadow-lg max-w-4xl w-full mx-auto p-6 border border-border relative z-10" phx-window-keydown="close_modal" phx-key="escape">
              <div class="flex justify-between items-center mb-4">
                <h3 class="text-lg font-medium">User Data Export</h3>
                <button phx-click="close_modal" class="text-muted-foreground hover:text-foreground rounded-full p-1 focus:outline-none focus:ring-2 focus:ring-ring">
                  <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>
              <div class="mb-4">
                <p class="text-sm text-muted-foreground mb-4">
                  Exporting data for user: <span class="font-medium"><%= @selected_user.email %></span>
                </p>

                <%= if @exported_data do %>
                  <div class="bg-muted p-4 rounded-md mb-4">
                    <pre class="text-xs overflow-auto max-h-96"><%= @exported_data %></pre>
                  </div>

                  <div class="flex justify-end">
                    <a
                      href={"data:application/json;charset=utf-8,#{URI.encode_www_form(@exported_data)}"}
                      download={"#{@selected_user.email}_export.json"}
                      class="inline-flex items-center justify-center rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 bg-primary text-primary-foreground hover:bg-primary/90 h-10 px-4 py-2"
                    >
                      Download JSON
                    </a>
                  </div>
                <% else %>
                  <div class="flex justify-center">
                    <button phx-click="export_user_data" class="inline-flex items-center justify-center rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 bg-primary text-primary-foreground hover:bg-primary/90 h-10 px-4 py-2">
                      Generate Export
                    </button>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Consent Management Modal -->
        <%= if @show_consent_modal do %>
          <div class="fixed inset-0 bg-background/80 backdrop-blur-sm flex items-center justify-center z-50">
            <div class="absolute inset-0" phx-click="close_modal"></div>
            <div class="bg-card rounded-lg shadow-lg max-w-md w-full mx-auto p-6 border border-border relative z-10" phx-window-keydown="close_modal" phx-key="escape">
              <div class="flex justify-between items-center mb-4">
                <h3 class="text-lg font-medium">Manage User Consent</h3>
                <button phx-click="close_modal" class="text-muted-foreground hover:text-foreground rounded-full p-1 focus:outline-none focus:ring-2 focus:ring-ring">
                  <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>
              <.form for={%{}} phx-submit="save_consent" phx-change="validate_consent">
                <div class="mb-4">
                  <label for="consent_type" class="block text-sm font-medium text-foreground mb-1">Consent Type</label>
                  <select
                    id="consent_type"
                    name="consent[consent_type]"
                    required
                    class="flex h-10 w-full items-center justify-between rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    <option value="">Select a consent type</option>
                    <%= for consent_type <- @consent_types do %>
                      <option value={consent_type.id}><%= consent_type.name %></option>
                    <% end %>
                  </select>
                </div>

                <div class="mb-4">
                  <label for="consent_status" class="block text-sm font-medium text-foreground mb-1">Consent Status</label>
                  <select
                    id="consent_status"
                    name="consent[consent_given]"
                    required
                    class="flex h-10 w-full items-center justify-between rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    <option value="true">Granted</option>
                    <option value="false">Denied</option>
                  </select>
                </div>

                <div class="mb-4">
                  <label for="consent_ip_address" class="block text-sm font-medium text-foreground mb-1">IP Address</label>
                  <input
                    type="text"
                    id="consent_ip_address"
                    name="consent[ip_address]"
                    placeholder="127.0.0.1"
                    class="flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
                  />
                </div>

                <div class="mb-4">
                  <label for="consent_user_agent" class="block text-sm font-medium text-foreground mb-1">User Agent</label>
                  <input
                    type="text"
                    id="consent_user_agent"
                    name="consent[user_agent]"
                    placeholder="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
                    class="flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
                  />
                </div>

                <div class="flex justify-end mt-6 space-x-3">
                  <button
                    type="button"
                    phx-click="close_modal"
                    class="inline-flex items-center justify-center rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 border border-input bg-background hover:bg-accent hover:text-accent-foreground h-10 px-4 py-2"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    class="inline-flex items-center justify-center rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 bg-primary text-primary-foreground hover:bg-primary/90 h-10 px-4 py-2"
                  >
                    Save Consent
                  </button>
                </div>
              </.form>
            </div>
          </div>
        <% end %>

        <!-- Anonymize User Modal -->
        <%= if @show_anonymize_modal do %>
          <div class="fixed inset-0 bg-background/80 backdrop-blur-sm flex items-center justify-center z-50">
            <div class="absolute inset-0" phx-click="close_modal"></div>
            <div class="bg-card rounded-lg shadow-lg max-w-md w-full mx-auto p-6 border border-border relative z-10" phx-window-keydown="close_modal" phx-key="escape">
              <div class="flex justify-between items-center mb-4">
                <h3 class="text-lg font-medium text-warning">Anonymize User Data</h3>
                <button phx-click="close_modal" class="text-muted-foreground hover:text-foreground rounded-full p-1 focus:outline-none focus:ring-2 focus:ring-ring">
                  <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>
              <div class="mb-6">
                <div class="bg-warning/10 border-l-4 border-warning p-4 mb-4 rounded-r-sm">
                  <div class="flex">
                    <div class="flex-shrink-0">
                      <svg class="h-5 w-5 text-warning" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                      </svg>
                    </div>
                    <div class="ml-3">
                      <p class="text-sm text-foreground">
                        You are about to anonymize personal data for <strong><%= @selected_user.email %></strong>. This action:
                      </p>
                      <ul class="mt-2 text-sm text-foreground list-disc list-inside">
                        <li>Will replace personal identifiers with anonymized values</li>
                        <li>Disables MFA and clears MFA settings</li>
                        <li>Preserves system records for integrity</li>
                        <li>Cannot be undone</li>
                      </ul>
                    </div>
                  </div>
                </div>

                <p class="text-sm text-muted-foreground">
                  This complies with GDPR's "right to be forgotten" while maintaining system integrity. To completely delete all user data, use the Delete User function instead.
                </p>
              </div>

              <div class="flex justify-end space-x-3">
                <button
                  type="button"
                  phx-click="close_modal"
                  class="inline-flex items-center justify-center rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 border border-input bg-background hover:bg-accent hover:text-accent-foreground h-10 px-4 py-2"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  phx-click="anonymize_user"
                  class="inline-flex items-center justify-center rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 bg-warning text-warning-foreground hover:bg-warning/90 h-10 px-4 py-2"
                >
                  Confirm Anonymization
                </button>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Delete User Modal -->
        <%= if @show_delete_modal do %>
          <div class="fixed inset-0 bg-background/80 backdrop-blur-sm flex items-center justify-center z-50">
            <div class="absolute inset-0" phx-click="close_modal"></div>
            <div class="bg-card rounded-lg shadow-lg max-w-md w-full mx-auto p-6 border border-border relative z-10" phx-window-keydown="close_modal" phx-key="escape">
              <div class="flex justify-between items-center mb-4">
                <h3 class="text-lg font-medium text-destructive">Delete User</h3>
                <button phx-click="close_modal" class="text-muted-foreground hover:text-foreground rounded-full p-1 focus:outline-none focus:ring-2 focus:ring-ring">
                  <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>
              <div class="mb-6">
                <div class="bg-destructive/10 border-l-4 border-destructive p-4 mb-4 rounded-r-sm">
                  <div class="flex">
                    <div class="flex-shrink-0">
                      <svg class="h-5 w-5 text-destructive" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                      </svg>
                    </div>
                    <div class="ml-3">
                      <p class="text-sm text-foreground">
                        You are about to <strong>permanently delete</strong> user <strong><%= @selected_user.email %></strong> and all associated data. This action:
                      </p>
                      <ul class="mt-2 text-sm text-foreground list-disc list-inside">
                        <li>Deletes all personal data including profile, authentication settings, and consent records</li>
                        <li>Removes all related records from the database</li>
                        <li>Cannot be undone</li>
                      </ul>
                    </div>
                  </div>
                </div>

                <p class="text-sm text-muted-foreground">
                  This action is permanent and cannot be undone. Consider using anonymization instead if you need to maintain system integrity.
                </p>
              </div>

              <div class="flex justify-end space-x-3">
                <button
                  type="button"
                  phx-click="close_modal"
                  class="inline-flex items-center justify-center rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 border border-input bg-background hover:bg-accent hover:text-accent-foreground h-10 px-4 py-2"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  phx-click="delete_user"
                  class="inline-flex items-center justify-center rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 bg-destructive text-destructive-foreground hover:bg-destructive/90 h-10 px-4 py-2"
                >
                  Permanently Delete User
                </button>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end
end
