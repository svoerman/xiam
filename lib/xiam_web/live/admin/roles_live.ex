defmodule XIAMWeb.Admin.RolesLive do
  use XIAMWeb, :live_view

  import XIAMWeb.Components.UI.Button
  import XIAMWeb.CoreComponents, except: [button: 1]

  alias XIAM.RBAC.Role
  alias XIAM.RBAC.Capability
  alias XIAM.Repo
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    IO.puts("==========================================")
    IO.puts("DEBUG: RolesLive mount function called")

    roles_query = from r in Role, order_by: r.name, preload: [:capabilities]
    roles = Repo.all(roles_query)
    capabilities = Capability.list_capabilities()

    # Create empty changesets for new roles and capabilities
    role_changeset = Role.changeset(%Role{}, %{})
    capability_changeset = Capability.changeset(%Capability{}, %{})

    socket = assign(socket,
      page_title: "Manage Roles & Capabilities",
      roles: roles,
      capabilities: capabilities,
      selected_role: nil,
      selected_capability: nil,
      show_role_modal: false,
      show_capability_modal: false,
      show_test_modal: false,
      form_mode: nil, # :new_role, :edit_role, :new_capability, :edit_capability
      role_changeset: role_changeset,
      capability_changeset: capability_changeset
    )

    IO.puts("DEBUG: Mount completed with assigns:")
    IO.inspect(socket.assigns, label: "Socket Assigns", pretty: true)

    {:ok, socket}
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
    IO.puts("DEBUG: show_new_role_modal event triggered")
    IO.inspect(socket.assigns, label: "Socket Assigns Before", pretty: true)

    role_changeset = Role.changeset(%Role{}, %{})
    result = assign(socket,
      show_role_modal: true,
      form_mode: :new_role,
      selected_role: nil,
      role_changeset: role_changeset
    )

    IO.inspect(result.assigns, label: "Socket Assigns After", pretty: true)
    {:noreply, result |> put_flash(:info, "Opening new role modal")}
  end

  def handle_event("show_edit_role_modal", %{"id" => id}, socket) do
    role = Repo.get(Role, id) |> Repo.preload(:capabilities)
    role_changeset = Role.changeset(role, %{})
    {:noreply, assign(socket,
      show_role_modal: true,
      form_mode: :edit_role,
      selected_role: role,
      role_changeset: role_changeset
    )}
  end

  def handle_event("show_new_capability_modal", _params, socket) do
    IO.puts("DEBUG: show_new_capability_modal event triggered")
    IO.inspect(socket.assigns, label: "Socket Assigns Before", pretty: true)

    capability_changeset = Capability.changeset(%Capability{}, %{})
    result = assign(socket,
      show_capability_modal: true,
      form_mode: :new_capability,
      selected_capability: nil,
      capability_changeset: capability_changeset
    )

    IO.inspect(result.assigns, label: "Socket Assigns After", pretty: true)
    {:noreply, result |> put_flash(:info, "Opening new capability modal")}
  end

  def handle_event("show_edit_capability_modal", %{"id" => id}, socket) do
    capability = Repo.get(Capability, id)
    capability_changeset = Capability.changeset(capability, %{})
    {:noreply, assign(socket,
      show_capability_modal: true,
      form_mode: :edit_capability,
      selected_capability: capability,
      capability_changeset: capability_changeset
    )}
  end

  def handle_event("close_modal", _, socket) do
    # Create fresh changesets
    role_changeset = Role.changeset(%Role{}, %{})
    capability_changeset = Capability.changeset(%Capability{}, %{})

    {:noreply, assign(socket,
      show_role_modal: false,
      show_capability_modal: false,
      form_mode: nil,
      role_changeset: role_changeset,
      capability_changeset: capability_changeset
    )}
  end

  def handle_event("save_role", %{"role" => role_params}, socket) do
    IO.puts("==========================================")
    IO.puts("EVENT: save_role event triggered with params: #{inspect(role_params)}")

    case socket.assigns.form_mode do
      :new_role ->
        case Role.create_role(role_params) do
          {:ok, _role} ->
            roles = refresh_roles(socket)
            role_changeset = Role.changeset(%Role{}, %{})

            {:noreply, socket
              |> assign(roles: roles, show_role_modal: false, role_changeset: role_changeset)
              |> put_flash(:info, "Role created successfully")}

          {:error, changeset} ->
            {:noreply, assign(socket, role_changeset: changeset)}
        end

      :edit_role ->
        case socket.assigns.selected_role do
          nil ->
            {:noreply, socket |> put_flash(:error, "No role selected")}
          role ->
            case Role.update_role(role, role_params) do
              {:ok, updated_role} ->
                roles = refresh_roles(socket)
                role_changeset = Role.changeset(%Role{}, %{})

                {:noreply, socket
                  |> assign(roles: roles, selected_role: updated_role, show_role_modal: false, role_changeset: role_changeset)
                  |> put_flash(:info, "Role updated successfully")}

              {:error, changeset} ->
                {:noreply, assign(socket, role_changeset: changeset)}
            end
        end

      _other ->
        {:noreply, socket |> put_flash(:error, "Invalid form mode")}
    end
  end

  def handle_event("save_capability", %{"capability" => capability_params}, socket) do
    IO.puts("==========================================")
    IO.puts("EVENT: save_capability event triggered with params: #{inspect(capability_params)}")

    case socket.assigns.form_mode do
      :new_capability ->
        case Capability.create_capability(capability_params) do
          {:ok, _capability} ->
            capabilities = Capability.list_capabilities()
            capability_changeset = Capability.changeset(%Capability{}, %{})

            {:noreply, socket
              |> assign(capabilities: capabilities, show_capability_modal: false, capability_changeset: capability_changeset)
              |> put_flash(:info, "Capability created successfully")}

          {:error, changeset} ->
            {:noreply, assign(socket, capability_changeset: changeset)}
        end

      :edit_capability ->
        case socket.assigns.selected_capability do
          nil ->
            {:noreply, socket |> put_flash(:error, "No capability selected")}
          capability ->
            case Capability.update_capability(capability, capability_params) do
              {:ok, updated_capability} ->
                capabilities = Capability.list_capabilities()
                capability_changeset = Capability.changeset(%Capability{}, %{})

                {:noreply, socket
                  |> assign(capabilities: capabilities, selected_capability: updated_capability, show_capability_modal: false, capability_changeset: capability_changeset)
                  |> put_flash(:info, "Capability updated successfully")}

              {:error, changeset} ->
                {:noreply, assign(socket, capability_changeset: changeset)}
            end
        end

      _other ->
        {:noreply, socket |> put_flash(:error, "Invalid form mode")}
    end
  end

  def handle_event("update_role_capabilities", %{"capability_ids" => capability_ids}, socket) do
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

  def handle_event("debug_click", _params, socket) do
    IO.puts("Debug button clicked! LiveView events are working!")
    {:noreply, socket |> put_flash(:info, "Debug button works! LiveView events are functional.")}
  end

  def handle_event("debug_modal", _params, socket) do
    IO.puts("Debug modal button clicked!")
    {:noreply, socket
      |> assign(show_role_modal: true)
      |> put_flash(:info, "Debug modal opened")}
  end

  def handle_event("close_test_modal", _params, socket) do
    IO.puts("Close test modal button clicked!")
    {:noreply, socket |> assign(show_test_modal: false) |> put_flash(:info, "Test modal close button works!")}
  end

  def handle_event("show_test_modal", _params, socket) do
    IO.puts("Show test modal button clicked!")
    {:noreply, socket |> assign(show_test_modal: true) |> put_flash(:info, "Showing test modal")}
  end

  # Private helpers

  defp refresh_roles(_socket) do
    roles_query = from r in Role, order_by: r.name, preload: [:capabilities]
    Repo.all(roles_query)
  end
end
