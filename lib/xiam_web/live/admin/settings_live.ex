defmodule XIAMWeb.Admin.SettingsLive do
  use XIAMWeb, :live_view
  
  #alias XIAM.Repo
  alias XIAM.System.Settings
  alias XIAM.Audit
  import XIAMWeb.CoreComponents
  
  @impl true
  def mount(_params, _session, socket) do
    theme = if connected?(socket), do: get_connect_params(socket)["theme"], else: "light"

    # Get settings from the database through our Settings module
    db_settings = Settings.list_settings()
    
    # Transform settings into our UI format
    settings = %{
      "general" => get_general_settings(db_settings),
      "oauth" => get_oauth_settings(db_settings),
      "mfa" => get_mfa_settings(db_settings),
      "security" => get_security_settings(db_settings)
    }
    
    {:ok, assign(socket, 
      page_title: "System Settings",
      theme: theme || "light",
      active_tab: "general",
      settings: settings,
      show_edit_modal: false,
      edit_section: nil,
      edit_key: nil,
      edit_value: nil
    )}
  end

  @impl true
  def handle_params(%{"tab" => tab}, _uri, socket) when tab in ["general", "oauth", "mfa", "security"] do
    {:noreply, assign(socket, active_tab: tab)}
  end
  
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/settings?tab=#{tab}")}
  end
  
  def handle_event("show_edit_modal", %{"section" => section, "key" => key}, socket) do
    current_value = get_in(socket.assigns.settings, [section, key])
    
    {:noreply, assign(socket,
      show_edit_modal: true,
      edit_section: section,
      edit_key: key,
      edit_value: current_value
    )}
  end
  
  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, show_edit_modal: false)}
  end

  def handle_event("toggle_theme", _, socket) do
    new_theme = if socket.assigns.theme == "light", do: "dark", else: "light"
    {:noreply, assign(socket, theme: new_theme)}
  end
  
  def handle_event("save_setting", %{"setting" => %{"value" => value}}, socket) do
    %{edit_section: section, edit_key: key} = socket.assigns
    current_user = socket.assigns[:current_user]
    
    # Save setting to the database using our Settings module
    setting_key = db_setting_key(section, key)
    case Settings.update_setting(setting_key, value) do
      {:ok, _updated_setting} ->
        # Log the action in audit logs
        Audit.log_action("update_setting", %{key: setting_key, value: value}, current_user)
        
        # Update local settings map
        settings = update_in(socket.assigns.settings, [section, key], fn _ -> value end)
        
        # Refresh settings cache
        Settings.refresh_cache()
        
        {:noreply, socket 
          |> assign(settings: settings, show_edit_modal: false)
          |> put_flash(:info, "Setting updated successfully")}
      
      {:error, changeset} ->
        error_message = format_changeset_errors(changeset)
        {:noreply, socket 
          |> put_flash(:error, "Failed to update setting: #{error_message}")
          |> assign(show_edit_modal: true)}
    end
  end
  
  # Private helper functions to get different setting categories from the database
  
  defp get_general_settings(db_settings) do
    %{
      "application_name" => get_setting_value(db_settings, "application_name", "XIAM"),
      "support_email" => get_setting_value(db_settings, "support_email", "support@example.com"),
      "allow_registration" => get_setting_value(db_settings, "allow_registration", "true"),
      "default_locale" => get_setting_value(db_settings, "default_locale", "en")
    }
  end
  
  defp get_oauth_settings(db_settings) do
    %{
      "github_enabled" => get_setting_value(db_settings, "github_enabled", "false"),
      "github_client_id" => get_setting_value(db_settings, "github_client_id", ""),
      "github_client_secret" => get_setting_value(db_settings, "github_client_secret", "[REDACTED]"),
      
      "google_enabled" => get_setting_value(db_settings, "google_enabled", "false"),
      "google_client_id" => get_setting_value(db_settings, "google_client_id", ""),
      "google_client_secret" => get_setting_value(db_settings, "google_client_secret", "[REDACTED]")
    }
  end
  
  defp get_mfa_settings(db_settings) do
    %{
      "mfa_required" => get_setting_value(db_settings, "mfa_required", "false"),
      "mfa_grace_period" => get_setting_value(db_settings, "mfa_grace_period", "7"),
      "totp_issuer" => get_setting_value(db_settings, "totp_issuer", "XIAM"),
      "backup_codes_count" => get_setting_value(db_settings, "backup_codes_count", "10")
    }
  end
  
  defp get_security_settings(db_settings) do
    %{
      "minimum_password_length" => get_setting_value(db_settings, "minimum_password_length", "8"),
      "password_requires_uppercase" => get_setting_value(db_settings, "password_requires_uppercase", "true"),
      "password_requires_number" => get_setting_value(db_settings, "password_requires_number", "true"),
      "password_requires_special" => get_setting_value(db_settings, "password_requires_special", "true"),
      "session_timeout_minutes" => get_setting_value(db_settings, "session_timeout_minutes", "60"),
      "jwt_token_expiry_hours" => get_setting_value(db_settings, "jwt_token_expiry_hours", "24"),
      "audit_logs_retention_days" => get_setting_value(db_settings, "audit_logs_retention_days", "90"),
      "consent_retention_days" => get_setting_value(db_settings, "consent_retention_days", "365"),
      "inactive_account_days" => get_setting_value(db_settings, "inactive_account_days", "365"),
      "api_rate_limit" => get_setting_value(db_settings, "api_rate_limit", "100")
    }
  end
  
  # Helper function to get setting value from the list of settings
  defp get_setting_value(db_settings, key, default) do
    Enum.find_value(db_settings, default, fn setting ->
      if setting.key == key, do: setting.value, else: nil
    end)
  end
  
  # Convert UI section/key to database key
  defp db_setting_key(_section, key) do
    key
  end
  
  # Format changeset errors for display
  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {k, v} -> "#{k}: #{Enum.join(v, ", ")}" end)
    |> Enum.join("; ")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["min-h-screen", @theme]} phx-hook="Theme" id="theme-container">
    <div class="container mx-auto px-4 py-8 bg-background text-foreground">
      <div class="flex justify-between items-center mb-8">
        <div>
          <h1 class="text-3xl font-bold text-foreground">System Settings</h1>
          <div class="text-sm text-muted-foreground">
            Configure system settings, OAuth providers, MFA, and security options
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

      <div class="bg-card text-card-foreground rounded-lg shadow-sm border border-border overflow-hidden">
        <div class="border-b border-border">
          <nav class="-mb-px flex" aria-label="Tabs">
            <button 
              phx-click="change_tab"
              phx-value-tab="general"
              class={"w-1/4 py-4 px-1 text-center border-b-2 font-medium text-sm #{if @active_tab == "general", do: "border-primary text-primary", else: "border-transparent text-muted-foreground hover:text-foreground hover:border-muted-foreground"}"}>
              General
            </button>
            <button 
              phx-click="change_tab"
              phx-value-tab="oauth"
              class={"w-1/4 py-4 px-1 text-center border-b-2 font-medium text-sm #{if @active_tab == "oauth", do: "border-primary text-primary", else: "border-transparent text-muted-foreground hover:text-foreground hover:border-muted-foreground"}"}>
              OAuth Providers
            </button>
            <button 
              phx-click="change_tab"
              phx-value-tab="mfa"
              class={"w-1/4 py-4 px-1 text-center border-b-2 font-medium text-sm #{if @active_tab == "mfa", do: "border-primary text-primary", else: "border-transparent text-muted-foreground hover:text-foreground hover:border-muted-foreground"}"}>
              Multi-Factor Auth
            </button>
            <button 
              phx-click="change_tab"
              phx-value-tab="security"
              class={"w-1/4 py-4 px-1 text-center border-b-2 font-medium text-sm #{if @active_tab == "security", do: "border-primary text-primary", else: "border-transparent text-muted-foreground hover:text-foreground hover:border-muted-foreground"}"}>
              Security
            </button>
          </nav>
        </div>
        
        <div class="p-6">
          <%= case @active_tab do %>
            <% "general" -> %>
              <div>
                <h2 class="text-lg font-medium text-foreground mb-4">General Settings</h2>
                <div class="overflow-hidden rounded-md border border-border">
                  <table class="min-w-full divide-y divide-border">
                    <tbody class="bg-background divide-y divide-border">
                      <%= for {key, value} <- @settings["general"] do %>
                        <tr>
                          <td class="px-6 py-4 whitespace-nowrap">
                            <div class="text-sm font-medium text-foreground"><%= format_key(key) %></div>
                          </td>
                          <td class="px-6 py-4 whitespace-nowrap">
                            <div class="text-sm text-muted-foreground"><%= format_value(key, value) %></div>
                          </td>
                          <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                            <button phx-click="show_edit_modal" phx-value-section="general" phx-value-key={key} class="text-primary hover:text-primary/80 transition-colors">
                              Edit
                            </button>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </div>
            
            <% "oauth" -> %>
              <div>
                <h2 class="text-lg font-medium text-foreground mb-4">OAuth Provider Settings</h2>
                
                <!-- GitHub Settings -->
                <div class="mb-8">
                  <div class="flex justify-between items-center mb-2">
                    <h3 class="text-md font-medium text-foreground">GitHub</h3>
                    <div class={"px-2 py-1 rounded text-xs font-medium #{if @settings["oauth"]["github_enabled"] == "true", do: "bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-300", else: "bg-red-100 dark:bg-red-900/30 text-red-800 dark:text-red-300"}"}>
                      <%= if @settings["oauth"]["github_enabled"] == "true", do: "Enabled", else: "Disabled" %>
                    </div>
                  </div>
                  
                  <div class="overflow-hidden rounded-md border border-border">
                    <table class="min-w-full divide-y divide-gray-200">
                      <tbody class="bg-white divide-y divide-gray-200">
                        <%= for key <- ["github_enabled", "github_client_id", "github_client_secret"] do %>
                          <tr>
                            <td class="px-6 py-4 whitespace-nowrap">
                              <div class="text-sm font-medium text-foreground"><%= format_key(key) %></div>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap">
                              <div class="text-sm text-muted-foreground"><%= format_value(key, @settings["oauth"][key]) %></div>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                              <button phx-click="show_edit_modal" phx-value-section="oauth" phx-value-key={key} class="text-primary hover:text-primary/80 transition-colors">
                                Edit
                              </button>
                            </td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  </div>
                </div>
                
                <!-- Google Settings -->
                <div>
                  <div class="flex justify-between items-center mb-2">
                    <h3 class="text-md font-medium text-foreground">Google</h3>
                    <div class={"px-2 py-1 rounded text-xs font-medium #{if @settings["oauth"]["google_enabled"] == "true", do: "bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-300", else: "bg-red-100 dark:bg-red-900/30 text-red-800 dark:text-red-300"}"}>
                      <%= if @settings["oauth"]["google_enabled"] == "true", do: "Enabled", else: "Disabled" %>
                    </div>
                  </div>
                  
                  <div class="overflow-hidden rounded-md border border-border">
                    <table class="min-w-full divide-y divide-gray-200">
                      <tbody class="bg-white divide-y divide-gray-200">
                        <%= for key <- ["google_enabled", "google_client_id", "google_client_secret"] do %>
                          <tr>
                            <td class="px-6 py-4 whitespace-nowrap">
                              <div class="text-sm font-medium text-foreground"><%= format_key(key) %></div>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap">
                              <div class="text-sm text-muted-foreground"><%= format_value(key, @settings["oauth"][key]) %></div>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                              <button phx-click="show_edit_modal" phx-value-section="oauth" phx-value-key={key} class="text-primary hover:text-primary/80 transition-colors">
                                Edit
                              </button>
                            </td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>
            
            <% "mfa" -> %>
              <div>
                <h2 class="text-lg font-medium text-foreground mb-4">Multi-Factor Authentication Settings</h2>
                <div class="overflow-hidden rounded-md border border-gray-200">
                  <table class="min-w-full divide-y divide-border">
                    <tbody class="bg-background divide-y divide-border">
                      <%= for {key, value} <- @settings["mfa"] do %>
                        <tr>
                          <td class="px-6 py-4 whitespace-nowrap">
                            <div class="text-sm font-medium text-foreground"><%= format_key(key) %></div>
                          </td>
                          <td class="px-6 py-4 whitespace-nowrap">
                            <div class="text-sm text-muted-foreground"><%= format_value(key, value) %></div>
                          </td>
                          <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                            <button phx-click="show_edit_modal" phx-value-section="mfa" phx-value-key={key} class="text-blue-600 hover:text-blue-900">
                              Edit
                            </button>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </div>
            
            <% "security" -> %>
              <div>
                <h2 class="text-lg font-medium text-foreground mb-4">Security Settings</h2>
                <div class="overflow-hidden rounded-md border border-gray-200">
                  <table class="min-w-full divide-y divide-border">
                    <tbody class="bg-background divide-y divide-border">
                      <%= for {key, value} <- @settings["security"] do %>
                        <tr>
                          <td class="px-6 py-4 whitespace-nowrap">
                            <div class="text-sm font-medium text-foreground"><%= format_key(key) %></div>
                          </td>
                          <td class="px-6 py-4 whitespace-nowrap">
                            <div class="text-sm text-muted-foreground"><%= format_value(key, value) %></div>
                          </td>
                          <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                            <button phx-click="show_edit_modal" phx-value-section="security" phx-value-key={key} class="text-blue-600 hover:text-blue-900">
                              Edit
                            </button>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </div>
          <% end %>
        </div>
      </div>
      
      <!-- Edit Setting Modal -->
      <%= if @show_edit_modal do %>
        <div class="fixed inset-0 bg-background/80 backdrop-blur-sm flex items-center justify-center z-50">
          <div class="bg-card text-card-foreground rounded-lg shadow-xl max-w-md w-full mx-auto p-6 border border-border">
            <div class="flex justify-between items-center mb-4">
              <h3 class="text-lg font-medium text-foreground">Edit Setting</h3>
              <button phx-click="close_modal" class="text-muted-foreground hover:text-foreground transition-colors">
                <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            
            <.form for={%{}} phx-submit="save_setting">
              <div class="mb-4">
                <label class="block text-sm font-medium text-foreground mb-1"><%= format_key(@edit_key) %></label>
                
                <%= case value_type(@edit_key) do %>
                  <% :boolean -> %>
                    <select name="setting[value]" class="block w-full p-2 bg-background border border-input rounded-md shadow-sm text-foreground focus:ring-2 focus:ring-primary/25 focus:border-primary">
                      <option value="true" selected={@edit_value == "true"}>Yes</option>
                      <option value="false" selected={@edit_value == "false"}>No</option>
                    </select>
                    
                  <% :number -> %>
                    <input type="number" name="setting[value]" value={@edit_value}
                      class="block w-full p-2 bg-background border border-input rounded-md shadow-sm text-foreground focus:ring-2 focus:ring-primary/25 focus:border-primary" />
                    
                  <% :sensitive -> %>
                    <input type="password" name="setting[value]" placeholder="Enter new value to change"
                      class="block w-full p-2 bg-background border border-input rounded-md shadow-sm text-foreground focus:ring-2 focus:ring-primary/25 focus:border-primary" />
                    <p class="mt-1 text-xs text-muted-foreground">Leave empty to keep current value</p>
                    
                  <% :text -> %>
                    <input type="text" name="setting[value]" value={@edit_value}
                      class="block w-full p-2 bg-background border border-input rounded-md shadow-sm text-foreground focus:ring-2 focus:ring-primary/25 focus:border-primary" />
                <% end %>
              </div>
              
              <div class="flex justify-end mt-6">
                <button type="button" phx-click="close_modal" class="mr-3 px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500">
                  Cancel
                </button>
                <button type="submit" class="px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500">
                  Save
                </button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>
    </div>
    </div>
    """
  end
  
  # Helper functions for formatting and display
  
  defp format_key(key) do
    key
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
  
  defp format_value(key, value) do
    case value_type(key) do
      :boolean ->
        if value == "true", do: "Yes", else: "No"
      
      :sensitive ->
        if String.contains?(key, "secret") or String.contains?(key, "password"), do: "••••••••", else: value
      
      _ ->
        value
    end
  end
  
  defp value_type(key) do
    cond do
      String.ends_with?(key, "enabled") or
      String.starts_with?(key, "password_requires_") -> :boolean
      
      String.contains?(key, "length") or
      String.contains?(key, "timeout") or
      String.contains?(key, "expiry") or
      String.contains?(key, "period") or
      String.contains?(key, "count") -> :number
      
      String.contains?(key, "secret") or
      String.contains?(key, "password") -> :sensitive
      
      true -> :text
    end
  end
end
