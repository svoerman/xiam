defmodule XIAMWeb.Admin.UsersLive do
  use XIAMWeb, :live_view

  alias XIAM.Users.User
  alias XIAM.Users
  alias Xiam.Rbac.Role
  alias XIAM.Repo
  import Ecto.Query

  @impl true
  def mount(_params, session, socket) do
    theme = if connected?(socket), do: get_connect_params(socket)["theme"], else: "light"
    current_user = session["pow_user_id"]
    |> to_int()
    |> case do
      id when is_integer(id) -> Repo.get_by(User, id: id)
      _ -> nil
    end

    users_query = from u in User,
                  left_join: r in assoc(u, :role),
                  preload: [role: r],
                  order_by: [desc: u.inserted_at]

    users = Repo.all(users_query)
    roles = Repo.all(Role)

    {:ok, assign(socket,
      page_title: "Manage Users",
      theme: theme || "light",
      users: users,
      roles: roles,
      selected_user: nil,
      show_edit_modal: false,
      show_mfa_modal: false,
      show_passkey_modal: false,
      passkeys: [],
      current_user: current_user
    )}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    user = id
    |> to_int()
    |> case do
      int_id when is_integer(int_id) -> Users.get_user(int_id) |> Repo.preload(:role)
      _ -> nil
    end
    if user do
      {:noreply, assign(socket, selected_user: user)}
    else
      {:noreply, socket |> put_flash(:error, "User not found") |> push_patch(to: ~p"/admin/users")}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, selected_user: nil)}
  end

  @impl true
  def handle_event("show_edit_modal", %{"id" => id}, socket) do
    user = id
    |> to_int()
    |> case do
      int_id when is_integer(int_id) -> Users.get_user(int_id) |> Repo.preload(:role)
      _ -> nil
    end
    {:noreply, assign(socket, selected_user: user, show_edit_modal: true)}
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, show_edit_modal: false, show_mfa_modal: false, show_passkey_modal: false)}
  end

  def handle_event("update_user_role", %{"user" => %{"role_id" => role_id}}, socket) do
    role_id = if role_id == "", do: nil, else: role_id

    case socket.assigns.selected_user do
      nil ->
        {:noreply, socket |> put_flash(:error, "No user selected")}
      user ->
        case User.role_changeset(user, %{role_id: role_id}) |> Repo.update() do
          {:ok, _updated_user} ->
            users = refresh_users(socket)

            {:noreply, socket
              |> assign(users: users, show_edit_modal: false)
              |> assign(current_user: socket.assigns.current_user)
              |> put_flash(:info, "User role updated successfully")}

          {:error, changeset} ->
            {:noreply, socket |> put_flash(:error, "Failed to update user: #{inspect(changeset.errors)}")}
        end
    end
  end

  def handle_event("toggle_passkey", %{"id" => id}, socket) do
    user = id
    |> to_int()
    |> case do
      int_id when is_integer(int_id) -> Users.get_user(int_id) |> Repo.preload(:role)
      _ -> nil
    end
    
    case user.passkey_enabled do
      true ->
        # Disable passkeys
        case Users.update_user_passkey_settings(user, %{passkey_enabled: false}) do
          {:ok, _updated_user} ->
            users = refresh_users(socket)

            {:noreply, socket
              |> assign(users: users)
              |> put_flash(:info, "Passkeys disabled for user")}

          {:error, _changeset} ->
            {:noreply, socket |> put_flash(:error, "Failed to disable passkeys")}
        end

      false ->
        # Show passkey management modal
        passkeys = Users.list_user_passkeys(user)
        
        {:noreply, socket
          |> assign(
            selected_user: user,
            show_passkey_modal: true,
            passkeys: passkeys
          )}
    end
  end
  
  def handle_event("toggle_passkey_setting", %{"value" => value}, socket) do
    user = socket.assigns.selected_user
    enable = value == "on"

    case Users.update_user_passkey_settings(user, %{passkey_enabled: enable}) do
      {:ok, updated_user} ->
        users = refresh_users(socket)
        passkeys = if enable, do: Users.list_user_passkeys(updated_user), else: []

        {:noreply, socket
          |> assign(users: users, selected_user: updated_user, passkeys: passkeys)
          |> put_flash(:info, if(enable, do: "Passkeys enabled successfully", else: "Passkeys disabled successfully"))}

      {:error, _changeset} ->
        {:noreply, socket |> put_flash(:error, "Failed to update passkey settings")}
    end
  end
  
  def handle_event("toggle_mfa", %{"id" => id}, socket) do
    user = id
    |> to_int()
    |> case do
      int_id when is_integer(int_id) -> Users.get_user(int_id) |> Repo.preload(:role)
      _ -> nil
    end

    case user.mfa_enabled do
      true ->
        # Disable MFA
        case User.mfa_changeset(user, %{mfa_enabled: false, mfa_secret: nil, mfa_backup_codes: nil}) |> Repo.update() do
          {:ok, _updated_user} ->
            users = refresh_users(socket)

            {:noreply, socket
              |> assign(users: users)
              |> put_flash(:info, "MFA disabled for user")}

          {:error, _changeset} ->
            {:noreply, socket |> put_flash(:error, "Failed to disable MFA")}
        end

      false ->
        # Show MFA setup modal
        mfa_secret = User.generate_totp_secret()
        backup_codes = User.generate_backup_codes()

        {:noreply, socket
          |> assign(
            selected_user: user,
            show_mfa_modal: true,
            mfa_secret: mfa_secret,
            backup_codes: backup_codes,
            qr_code_uri: NimbleTOTP.otpauth_uri("XIAM:#{user.email}", mfa_secret, issuer: "XIAM")
          )}
    end
  end

  def handle_event("enable_mfa", _params, socket) do
    user = socket.assigns.selected_user

    case User.mfa_changeset(user, %{
      mfa_enabled: true,
      mfa_secret: socket.assigns.mfa_secret,
      mfa_backup_codes: socket.assigns.backup_codes
    }) |> Repo.update() do
      {:ok, _updated_user} ->
        users = refresh_users(socket)

        {:noreply, socket
          |> assign(users: users, show_mfa_modal: false)
          |> put_flash(:info, "MFA enabled successfully")}

      {:error, _changeset} ->
        {:noreply, socket |> put_flash(:error, "Failed to enable MFA")}
    end
  end

  # Private helpers

  defp to_int(value) when is_integer(value), do: value
  defp to_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {i, ""} -> i
      _ -> nil
    end
  end
  defp to_int(_), do: nil

  defp refresh_users(_socket) do
    users_query = from u in User,
                  left_join: r in assoc(u, :role),
                  preload: [role: r],
                  order_by: [desc: u.inserted_at]

    Repo.all(users_query)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["min-h-screen", @theme]} phx-hook="Theme" id="theme-container">
    <div class="container mx-auto px-4 py-8 bg-background text-foreground">
      <.admin_header
        title="User Management"
        subtitle="Manage user accounts, roles, and multi-factor authentication settings"
      />

      <div class="bg-card text-card-foreground rounded-lg shadow-sm border border-border overflow-hidden">
        <div class="px-4 py-5 sm:px-6 bg-muted/50 border-b border-border">
          <h2 class="text-xl font-semibold text-foreground">Users</h2>
        </div>
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-border">
            <thead class="bg-muted/50">
              <tr>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">User</th>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">Role</th>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">MFA Status</th>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">Passkey Status</th>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">Joined</th>
                <th scope="col" class="px-6 py-3 text-right text-xs font-medium text-muted-foreground uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody class="bg-background divide-y divide-border">
              <%= for user <- @users do %>
                <tr>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="flex items-center">
                      <div class="ml-4">
                        <div class="text-sm font-medium text-foreground"><%= user.email %></div>
                        <div class="text-sm text-muted-foreground">ID: <%= user.id %></div>
                      </div>
                    </div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class={["px-2 inline-flex text-xs leading-5 font-semibold rounded-full", (if user.role, do: "bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-300", else: "bg-gray-100 dark:bg-gray-800/40 text-gray-800 dark:text-gray-300")]}>
                      <%= if user.role, do: user.role.name, else: "No Role" %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class={["px-2 inline-flex text-xs leading-5 font-semibold rounded-full", (if user.mfa_enabled, do: "bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-300", else: "bg-red-100 dark:bg-red-900/30 text-red-800 dark:text-red-300")]}>
                      <%= if user.mfa_enabled, do: "Enabled", else: "Disabled" %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class={["px-2 inline-flex text-xs leading-5 font-semibold rounded-full", (if user.passkey_enabled, do: "bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-300", else: "bg-red-100 dark:bg-red-900/30 text-red-800 dark:text-red-300")]}>
                      <%= if user.passkey_enabled, do: "Enabled", else: "Disabled" %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-muted-foreground">
                    <%= Calendar.strftime(user.inserted_at, "%Y-%m-%d %H:%M") %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                    <button class="text-primary hover:text-primary/80 mr-3 transition-colors" phx-click="show_edit_modal" phx-value-id={user.id}>
                      Edit
                    </button>
                    <button class={if user.mfa_enabled, do: "text-destructive hover:text-destructive/80", else: "text-green-600 hover:text-green-700 dark:text-green-400 dark:hover:text-green-500"} phx-click="toggle_mfa" phx-value-id={user.id} class="transition-colors mr-3">
                      <%= if user.mfa_enabled, do: "Disable MFA", else: "Enable MFA" %>
                    </button>
                    <button class={if user.passkey_enabled, do: "text-destructive hover:text-destructive/80", else: "text-green-600 hover:text-green-700 dark:text-green-400 dark:hover:text-green-500"} phx-click="toggle_passkey" phx-value-id={user.id} class="transition-colors">
                      <%= if user.passkey_enabled, do: "Manage Passkeys", else: "Enable Passkeys" %>
                    </button>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <%= if @show_edit_modal do %>
        <div class="fixed inset-0 bg-background/80 backdrop-blur-sm flex items-center justify-center z-50">
          <div class="bg-card text-card-foreground rounded-lg shadow-xl max-w-md w-full mx-auto p-6 border border-border">

            <div class="flex justify-between items-center mb-4">
              <h3 class="text-lg font-medium text-foreground">Edit User</h3>
              <button phx-click="close_modal" class="text-muted-foreground hover:text-foreground transition-colors">

                <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <div class="mb-4">
              <p class="text-sm text-muted-foreground">
                Editing user: <span class="font-medium"><%= @selected_user.email %></span>
              </p>
            </div>

            <.form for={%{}} phx-submit="update_user_role">
              <div class="mb-4">
                <label for="role_id" class="block text-sm font-medium text-foreground mb-1">Assign Role</label>
                <select id="role_id" name="user[role_id]" class="block w-full p-2 bg-background border border-input rounded-md shadow-sm text-foreground focus:ring-2 focus:ring-primary/25 focus:border-primary">
                  <option value="" selected={@selected_user.role_id == nil}>No Role</option>
                  <%= for role <- @roles do %>
                    <option value={role.id} selected={@selected_user.role_id == role.id}><%= role.name %></option>
                  <% end %>
                </select>
              </div>

              <div class="flex justify-end mt-6">
                <button type="button" phx-click="close_modal" class="mr-3 px-4 py-2 border border-input bg-background text-foreground rounded-md hover:bg-accent transition-colors text-sm">
                  Cancel
                </button>
                <button type="submit" class="px-4 py-2 bg-primary text-primary-foreground rounded-md hover:bg-primary/90 transition-colors text-sm">
                  Save Changes
                </button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>

      <%= if @show_mfa_modal do %>
        <div class="fixed inset-0 bg-background/80 backdrop-blur-sm flex items-center justify-center z-50">
          <div class="bg-card text-card-foreground rounded-lg shadow-xl max-w-lg w-full mx-auto p-6 border border-border">
            <div class="flex justify-between items-center mb-4">
              <h3 class="text-lg font-medium text-foreground">Enable Multi-Factor Authentication</h3>
              <button phx-click="close_modal" class="text-muted-foreground hover:text-foreground transition-colors">
                <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <div class="mb-6">
              <p class="text-sm text-muted-foreground mb-4">
                Enabling MFA for user: <span class="font-medium"><%= @selected_user.email %></span>
              </p>

              <div class="mb-4">
                <h4 class="font-medium mb-2 text-foreground">1. Scan this QR code with your authenticator app</h4>
                <div class="bg-muted p-4 rounded-md flex justify-center">
                  <div class="border border-border p-4 rounded-md bg-background">
                    <%= render_qr_code(assigns) %>
                  </div>
                  <div class="hidden"><%= @qr_code_uri %></div>
                </div>
              </div>

              <div class="mb-4">
                <h4 class="font-medium mb-2 text-foreground">2. Or enter this code manually</h4>
                <div class="bg-muted p-3 rounded-md font-mono text-center text-foreground">
                  <%= Base.encode32(@mfa_secret, padding: false) %>
                </div>
              </div>

              <div class="mb-4">
                <h4 class="font-medium mb-2 text-foreground">3. Save these backup codes (they will only be shown once)</h4>
                <div class="bg-muted p-3 rounded-md font-mono text-sm grid grid-cols-2 gap-2">
                  <%= for code <- @backup_codes do %>
                    <div class="bg-background p-1 rounded border border-border text-center text-foreground"><%= code %></div>
                  <% end %>
                </div>
              </div>
            </div>

            <div class="flex justify-end">
              <button type="button" phx-click="close_modal" class="mr-3 px-4 py-2 border border-input bg-background text-foreground rounded-md hover:bg-accent transition-colors text-sm">
                Cancel
              </button>
              <button type="button" phx-click="enable_mfa" class="px-4 py-2 bg-primary text-primary-foreground rounded-md hover:bg-primary/90 transition-colors text-sm">
                Enable MFA
              </button>
            </div>
          </div>
        </div>
      <% end %>
      
      <%= if @show_passkey_modal do %>
        <div class="fixed inset-0 bg-background/80 backdrop-blur-sm flex items-center justify-center z-50">
          <div class="bg-card text-card-foreground rounded-lg shadow-xl max-w-lg w-full mx-auto p-6 border border-border">
            <div class="flex justify-between items-center mb-4">
              <h3 class="text-lg font-medium text-foreground">Passkey Management</h3>
              <button class="text-muted-foreground hover:text-foreground transition-colors" phx-click="close_modal">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                </svg>
              </button>
            </div>
            
            <div class="mb-6">
              <p class="text-sm text-muted-foreground mb-4">
                Passkeys provide a more secure way to sign in without passwords. They use biometrics 
                (like fingerprint or face) or device PIN to authenticate.
              </p>
              
              <div class="flex items-center mb-4">
                <label class="inline-flex items-center cursor-pointer">
                  <input 
                    type="checkbox" 
                    class="sr-only peer"
                    checked={@selected_user.passkey_enabled}
                    phx-click="toggle_passkey_setting"
                  />
                  <div class="relative w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-primary-300 dark:peer-focus:ring-primary-800 rounded-full peer dark:bg-gray-700 peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:start-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all dark:border-gray-600 peer-checked:bg-primary-600"></div>
                  <span class="ms-3 text-sm font-medium text-gray-900 dark:text-gray-300">Enable Passkeys</span>
                </label>
              </div>
            </div>
            
            <%= if @selected_user.passkey_enabled do %>
              <div class="mb-6">
                <h4 class="text-md font-medium mb-2">Registered Passkeys</h4>
                <%= if Enum.empty?(@passkeys) do %>
                  <p class="text-sm text-muted-foreground italic">No passkeys registered yet.</p>
                <% else %>
                  <div class="overflow-x-auto">
                    <table class="min-w-full divide-y divide-border">
                      <thead class="bg-muted/50">
                        <tr>
                          <th scope="col" class="px-4 py-2 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">Name</th>
                          <th scope="col" class="px-4 py-2 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">Created</th>
                          <th scope="col" class="px-4 py-2 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">Last Used</th>
                        </tr>
                      </thead>
                      <tbody class="bg-background divide-y divide-border">
                        <%= for passkey <- @passkeys do %>
                          <tr>
                            <td class="px-4 py-2 whitespace-nowrap text-sm"><%= passkey.friendly_name %></td>
                            <td class="px-4 py-2 whitespace-nowrap text-sm"><%= Calendar.strftime(passkey.created_at, "%Y-%m-%d %H:%M") %></td>
                            <td class="px-4 py-2 whitespace-nowrap text-sm">
                              <%= if passkey.last_used_at do %>
                                <%= Calendar.strftime(passkey.last_used_at, "%Y-%m-%d %H:%M") %>
                              <% else %>
                                Never
                              <% end %>
                            </td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  </div>
                <% end %>
              </div>
              
              <p class="text-sm text-muted-foreground mb-4">
                Note: Currently, passkeys can only be managed by administrators. In the future, you may want to add passkey registration functionality to the user account settings page and login flow.
              </p>
            <% end %>
            
            <div class="flex justify-end mt-6">
              <button class="btn btn-primary" phx-click="close_modal">Close</button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    </div>
    """
  end

  def render_qr_code(assigns) do
    ~H"""
    <div class="flex justify-center">
      <%= if @qr_code_uri do %>
        <% qr = QRCode.create(@qr_code_uri) %>
        <% {:ok, svg} = QRCode.Render.render(qr, :svg, %QRCode.Render.SvgSettings{scale: 8}) %>
        <img src={"data:image/svg+xml;base64,#{Base.encode64(svg)}"} alt="QR Code" />
      <% end %>
    </div>
    """
  end
end
