defmodule XIAMWeb.PasskeyComponent do
  @moduledoc """
  LiveView component for managing passkeys.
  """
  use XIAMWeb, :live_component

  alias XIAM.Users

  @impl true
  def render(assigns) do
    ~H"""
    <div class="passkey-management">
      <h2 class="text-xl font-semibold mb-4">Passkey Management</h2>
      
      <div class="mb-6">
        <p class="mb-2">
          Passkeys provide a more secure way to sign in without passwords. They use biometrics 
          (like your fingerprint or face) or device PIN to authenticate.
        </p>
        
        <div class="flex items-center mt-4">
          <div class="form-control">
            <label class="label cursor-pointer">
              <span class="label-text mr-4">Enable Passkeys</span>
              <input
                type="checkbox"
                class="toggle toggle-primary"
                checked={@user.passkey_enabled}
                phx-click="toggle_passkey_enabled"
                phx-target={@myself}
              />
            </label>
          </div>
        </div>
      </div>

      <%= if @user.passkey_enabled do %>
        <div class="mb-6">
          <h3 class="text-lg font-medium mb-2">Register a New Passkey</h3>
          <div class="flex items-end gap-4">
            <div class="form-control w-full max-w-xs">
              <label class="label">
                <span class="label-text">Passkey Name</span>
              </label>
              <input
                type="text"
                placeholder="e.g. Work Laptop"
                class="input input-bordered w-full max-w-xs"
                value={@new_passkey_name}
                phx-keyup="update_passkey_name"
                phx-target={@myself}
              />
            </div>
            <button
              class="btn btn-primary"
              phx-click="register_passkey"
              phx-target={@myself}
              disabled={@new_passkey_name == ""}
            >
              Register Passkey
            </button>
          </div>
        </div>

        <div>
          <h3 class="text-lg font-medium mb-2">Your Passkeys</h3>
          <%= if Enum.empty?(@passkeys) do %>
            <p class="text-gray-500 italic">You haven't registered any passkeys yet.</p>
          <% else %>
            <div class="overflow-x-auto">
              <table class="table w-full">
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Created</th>
                    <th>Last Used</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for passkey <- @passkeys do %>
                    <tr>
                      <td><%= passkey.friendly_name %></td>
                      <td><%= format_datetime(passkey.created_at) %></td>
                      <td>
                        <%= if passkey.last_used_at do %>
                          <%= format_datetime(passkey.last_used_at) %>
                        <% else %>
                          Never
                        <% end %>
                      </td>
                      <td>
                        <button
                          class="btn btn-sm btn-error"
                          phx-click="delete_passkey"
                          phx-value-id={passkey.id}
                          phx-target={@myself}
                        >
                          Remove
                        </button>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- Registration Script -->
      <div phx-hook="PasskeyRegistration" id="passkey-registration" data-user-id={@user.id}></div>
      
      <!-- Flash Messages -->
      <%= if @flash["error"] do %>
        <div class="alert alert-error mt-4">
          <svg xmlns="http://www.w3.org/2000/svg" class="stroke-current shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
          <span><%= @flash["error"] %></span>
        </div>
      <% end %>
      
      <%= if @flash["info"] do %>
        <div class="alert alert-info mt-4">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="stroke-current shrink-0 w-6 h-6"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
          <span><%= @flash["info"] %></span>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:new_passkey_name, fn -> "" end)
      |> assign_new(:flash, fn -> %{} end)
      |> assign_passkeys()

    {:ok, socket}
  end

  @impl true
  def handle_event("update_passkey_name", %{"value" => name}, socket) do
    {:noreply, assign(socket, new_passkey_name: name)}
  end

  @impl true
  def handle_event("toggle_passkey_enabled", _params, socket) do
    user = socket.assigns.user
    
    case Users.update_user_passkey_settings(user, %{passkey_enabled: !user.passkey_enabled}) do
      {:ok, updated_user} ->
        socket = 
          socket
          |> assign(user: updated_user)
          |> put_flash_message(:info, "Passkey settings updated successfully")
        
        {:noreply, socket}
        
      {:error, _changeset} ->
        socket = put_flash_message(socket, :error, "Failed to update passkey settings")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("register_passkey", _params, socket) do
    # This will trigger the client-side JavaScript hook
    # The actual registration happens via API calls from the client
    send_update(self(), :trigger_passkey_registration, %{
      name: socket.assigns.new_passkey_name
    })
    
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_passkey", %{"id" => id}, socket) do
    case Users.delete_user_passkey(socket.assigns.user, id) do
      {:ok, _} ->
        socket = 
          socket
          |> assign_passkeys()
          |> put_flash_message(:info, "Passkey removed successfully")
        
        {:noreply, socket}
        
      {:error, reason} ->
        socket = put_flash_message(socket, :error, "Failed to remove passkey: #{reason}")
        {:noreply, socket}
    end
  end

  # Private helper functions
  
  defp assign_passkeys(socket) do
    passkeys = Users.list_user_passkeys(socket.assigns.user)
    assign(socket, passkeys: passkeys)
  end
  
  defp put_flash_message(socket, key, message) do
    assign(socket, flash: Map.put(socket.assigns.flash, to_string(key), message))
  end
  
  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  end
end
