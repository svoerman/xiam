defmodule XIAMWeb.AccountSettingsLive do
  @moduledoc """
  LiveView for user account settings, including passkey management.
  """
  use XIAMWeb, :live_view

  alias XIAM.Users
  
  @impl true
  def mount(_params, _session, socket) do
    socket = clear_flash(socket)
    user = socket.assigns.current_user
    
    if user do
      passkeys = Users.list_user_passkeys(user)
      theme = socket.assigns[:theme] || "light"
      
      {:ok, assign(socket,
        user: user,
        current_user: user,
        passkeys: passkeys,
        theme: theme,
        page_title: "Account Settings",
        show_passkey_modal: false,
        new_passkey_name: ""
      )}
    else
      {:ok, redirect(socket, to: ~p"/session/new")}
    end
  end

  @impl true
  def handle_event("toggle_theme", _, socket) do
    current_theme = socket.assigns.theme
    new_theme = if current_theme == "dark", do: "light", else: "dark"
    
    {:noreply, assign(socket, theme: new_theme)}
  end

  @impl true
  def handle_event("show_passkey_modal", _, socket) do
    {:noreply, assign(socket, show_passkey_modal: true)}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, show_passkey_modal: false)}
  end

  @impl true
  def handle_event("save_passkey_name", %{"passkey" => %{"name" => name}}, socket) do
    # Validate the name is not empty
    if String.trim(name) == "" do
      {:noreply, put_flash(socket, :error, "Passkey name cannot be empty")}
    else
      # Send an event to the client to start the passkey registration process
      {:noreply, push_event(socket, "trigger_passkey_registration", %{name: name})}
    end
  end

  @impl true
  def handle_event("delete_passkey", %{"id" => id}, socket) do
    user = socket.assigns.user
    
    case Users.delete_user_passkey(user, id) do
      {:ok, _} ->
        passkeys = Users.list_user_passkeys(user)
        {:noreply, socket 
          |> assign(passkeys: passkeys)
          |> put_flash(:info, "Passkey deleted successfully")}
        
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete passkey")}
    end
  end

  # Handle the event when a passkey is successfully registered
  @impl true
  def handle_event("passkey_registered", _params, socket) do
    user = socket.assigns.user
    passkeys = Users.list_user_passkeys(user)
    
    {:noreply, socket
      |> assign(passkeys: passkeys, show_passkey_modal: false)
      |> put_flash(:info, "Passkey registered successfully")}
  end

  # Handle passkey errors
  @impl true
  def handle_event("passkey_error", %{"message" => message}, socket) do
    {:noreply, put_flash(socket, :error, "Passkey error: #{message}")}
  end

  @impl true
  def handle_event("passkeys_loaded", %{"passkeys" => passkeys}, socket) do
    {:noreply, assign(socket, passkeys: passkeys)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["min-h-screen", @theme]} phx-hook="Theme" id="theme-container">
      <div class="container mx-auto px-4 py-8 bg-background text-foreground">
        <div class="flex justify-between items-center mb-8">
          <h1 class="text-2xl font-bold">Account Settings</h1>
          <div class="flex items-center space-x-4">
            <button phx-click="toggle_theme" class="p-2 rounded-full hover:bg-accent transition-colors">
              <%= if @theme == "dark" do %>
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M10 2a1 1 0 011 1v1a1 1 0 11-2 0V3a1 1 0 011-1zm4 8a4 4 0 11-8 0 4 4 0 018 0zm-.464 4.95l.707.707a1 1 0 001.414-1.414l-.707-.707a1 1 0 00-1.414 1.414zm2.12-10.607a1 1 0 010 1.414l-.706.707a1 1 0 11-1.414-1.414l.707-.707a1 1 0 011.414 0zM17 11a1 1 0 100-2h-1a1 1 0 100 2h1zm-7 4a1 1 0 011 1v1a1 1 0 11-2 0v-1a1 1 0 011-1zM5.05 6.464A1 1 0 106.465 5.05l-.708-.707a1 1 0 00-1.414 1.414l.707.707zm1.414 8.486l-.707.707a1 1 0 01-1.414-1.414l.707-.707a1 1 0 011.414 1.414zM4 11a1 1 0 100-2H3a1 1 0 000 2h1z" clip-rule="evenodd" />
                </svg>
              <% else %>
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                  <path d="M17.293 13.293A8 8 0 016.707 2.707a8.001 8.001 0 1010.586 10.586z" />
                </svg>
              <% end %>
            </button>
            <a href="/" class="text-sm text-primary hover:underline">Back to Home</a>
          </div>
        </div>
        
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <!-- Sidebar Navigation -->
          <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-4">
            <nav class="space-y-2">
              <a href="#account" class="block px-3 py-2 rounded-md bg-primary/10 text-primary font-medium">
                Account Information
              </a>
              <a href="#security" class="block px-3 py-2 rounded-md hover:bg-accent transition-colors">
                Security
              </a>
              <a href="#passkeys" class="block px-3 py-2 rounded-md hover:bg-accent transition-colors">
                Passkeys
              </a>
            </nav>
          </div>
          
          <!-- Main Content -->
          <div class="md:col-span-2 space-y-6">
            <!-- Account Information Section -->
            <section id="account" class="bg-card text-card-foreground rounded-lg border shadow-sm p-6">
              <h2 class="text-xl font-semibold mb-4">Account Information</h2>
              <div class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-muted-foreground mb-1">Email</label>
                  <div class="text-foreground"><%= @user.email %></div>
                </div>
                
                <div>
                  <label class="block text-sm font-medium text-muted-foreground mb-1">Name</label>
                  <div class="text-foreground"><%= @user.name || "Not set" %></div>
                </div>
                
                <div>
                  <label class="block text-sm font-medium text-muted-foreground mb-1">Account Created</label>
                  <div class="text-foreground"><%= Calendar.strftime(@user.inserted_at, "%Y-%m-%d %H:%M") %></div>
                </div>
              </div>
            </section>
            
            <!-- Security Section -->
            <section id="security" class="bg-card text-card-foreground rounded-lg border shadow-sm p-6">
              <h2 class="text-xl font-semibold mb-4">Security</h2>
              <div class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-muted-foreground mb-1">Multi-Factor Authentication</label>
                  <div class="flex items-center">
                    <span class={["px-2 py-1 inline-flex text-xs leading-5 font-semibold rounded-full", 
                      if(@user.mfa_enabled, do: "bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-300", 
                      else: "bg-red-100 dark:bg-red-900/30 text-red-800 dark:text-red-300")]}>
                      <%= if @user.mfa_enabled, do: "Enabled", else: "Disabled" %>
                    </span>
                  </div>
                </div>
                
                <div>
                  <label class="block text-sm font-medium text-muted-foreground mb-1">Passkey Authentication</label>
                  <div class="flex items-center">
                    <span class={["px-2 py-1 inline-flex text-xs leading-5 font-semibold rounded-full", 
                      if(@user.passkey_enabled, do: "bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-300", 
                      else: "bg-red-100 dark:bg-red-900/30 text-red-800 dark:text-red-300")]}>
                      <%= if @user.passkey_enabled, do: "Enabled", else: "Disabled" %>
                    </span>
                  </div>
                </div>
                
                <div>
                  <label class="block text-sm font-medium text-muted-foreground mb-1">Last Sign In</label>
                  <div class="text-foreground">
                    <%= if @user.last_sign_in_at do %>
                      <%= Calendar.strftime(@user.last_sign_in_at, "%Y-%m-%d %H:%M") %>
                    <% else %>
                      Not available
                    <% end %>
                  </div>
                </div>
              </div>
            </section>
            
            <!-- Passkeys Section -->
            <section id="passkeys" class="bg-card text-card-foreground rounded-lg border shadow-sm p-6" phx-hook="PasskeyManagement" id="passkey-management">
              <div class="flex justify-between items-center mb-4">
                <h2 class="text-xl font-semibold">Passkeys</h2>
                <button phx-click="show_passkey_modal" class="px-4 py-2 bg-primary text-primary-foreground rounded-md hover:bg-primary/90 transition-colors text-sm">
                  Add Passkey
                </button>
              </div>
              
              <p class="text-sm text-muted-foreground mb-4">
                Passkeys provide a more secure way to sign in without passwords. They use biometrics 
                (like fingerprint or face) or device PIN to authenticate.
              </p>
              
              <%= if Enum.empty?(@passkeys) do %>
                <div class="bg-muted p-4 rounded-md text-center text-muted-foreground">
                  No passkeys registered yet. Add a passkey to enable passwordless sign-in.
                </div>
              <% else %>
                <div class="overflow-x-auto">
                  <table class="min-w-full divide-y divide-border">
                    <thead class="bg-muted/50">
                      <tr>
                        <th scope="col" class="px-4 py-2 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">Name</th>
                        <th scope="col" class="px-4 py-2 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">Created</th>
                        <th scope="col" class="px-4 py-2 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">Last Used</th>
                        <th scope="col" class="px-4 py-2 text-right text-xs font-medium text-muted-foreground uppercase tracking-wider">Actions</th>
                      </tr>
                    </thead>
                    <tbody class="bg-background divide-y divide-border">
                      <%= for passkey <- @passkeys do %>
                        <tr>
                          <td class="px-4 py-2 whitespace-nowrap text-sm"><%= passkey.friendly_name %></td>
                          <td class="px-4 py-2 whitespace-nowrap text-sm">
                            <%= cond do
                                Map.has_key?(passkey, :inserted_at) -> Calendar.strftime(passkey.inserted_at, "%Y-%m-%d %H:%M")
                                Map.has_key?(passkey, :created_at) -> Calendar.strftime(passkey.created_at, "%Y-%m-%d %H:%M")
                                true -> "Unknown"
                              end %>
                          </td>
                          <td class="px-4 py-2 whitespace-nowrap text-sm">
                            <%= if passkey.last_used_at do %>
                              <%= Calendar.strftime(passkey.last_used_at, "%Y-%m-%d %H:%M") %>
                            <% else %>
                              Never
                            <% end %>
                          </td>
                          <td class="px-4 py-2 whitespace-nowrap text-sm text-right">
                            <button phx-click="delete_passkey" phx-value-id={passkey.id} class="text-destructive hover:text-destructive/80 transition-colors" data-confirm="Are you sure you want to delete this passkey?">
                              Delete
                            </button>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              <% end %>
            </section>
          </div>
        </div>
      </div>
      
      <%= if @show_passkey_modal do %>
        <div class="fixed inset-0 bg-background/80 backdrop-blur-sm flex items-center justify-center z-50">
          <div class="bg-card text-card-foreground rounded-lg shadow-xl max-w-md w-full mx-auto p-6 border border-border">
            <div class="flex justify-between items-center mb-4">
              <h3 class="text-lg font-medium text-foreground">Register New Passkey</h3>
              <button phx-click="close_modal" class="text-muted-foreground hover:text-foreground transition-colors">
                <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            
            <p class="text-sm text-muted-foreground mb-4">
              Give your passkey a name so you can identify it later. You'll be prompted to use your 
              device's authentication method (fingerprint, face, or PIN) to create the passkey.
            </p>
            
            <.form for={%{}} phx-submit="save_passkey_name" class="space-y-4" phx-hook="PasskeyRegistration" id="passkey-registration-form">
              <div>
                <label for="passkey_name" class="block text-sm font-medium text-foreground mb-1">Passkey Name</label>
                <input 
                  type="text" 
                  id="passkey_name" 
                  name="passkey[name]" 
                  placeholder="e.g., My iPhone, Work Laptop"
                  class="flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
                  required
                />
              </div>
              
              <div class="flex justify-end mt-6">
                <button type="button" phx-click="close_modal" class="mr-3 px-4 py-2 border border-input bg-background text-foreground rounded-md hover:bg-accent transition-colors text-sm">
                  Cancel
                </button>
                <button type="submit" class="px-4 py-2 bg-primary text-primary-foreground rounded-md hover:bg-primary/90 transition-colors text-sm">
                  Register Passkey
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
