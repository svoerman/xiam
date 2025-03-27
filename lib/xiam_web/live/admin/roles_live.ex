defmodule XIAMWeb.Admin.RolesLive do
  use XIAMWeb, :live_view

  import XIAMWeb.Components.UI.Button
  import XIAMWeb.Components.UI.Modal
  import XIAMWeb.CoreComponents, except: [button: 1, modal: 1]
  import XIAMWeb.Components.UI

  alias XIAM.RBAC
  alias XIAM.RBAC.Role
  alias XIAM.RBAC.Capability
  alias XIAM.Repo
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    roles = RBAC.list_roles()
    changeset = RBAC.change_capability(%Capability{})

    socket = assign(socket,
      page_title: "Roles & Capabilities",
      roles: roles,
      capabilities: RBAC.list_capabilities(),
      selected_role: nil,
      capability_changeset: changeset,
      selected_capability: nil,
      form_mode: nil,
      show_role_modal: false,
      show_capability_modal: false
    )

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
    role_changeset = Role.changeset(%Role{}, %{})
    {:noreply, assign(socket,
      show_role_modal: true,
      form_mode: :new_role,
      selected_role: nil,
      role_changeset: role_changeset
    )}
  end

  def handle_event("show_edit_role_modal", %{"id" => id}, socket) do
    role = Repo.get(Role, id) |> Repo.preload(:capabilities)
    role_changeset = Role.changeset(role, %{
      name: role.name,
      description: role.description
    })
    {:noreply, assign(socket,
      show_role_modal: true,
      form_mode: :edit_role,
      selected_role: role,
      role_changeset: role_changeset
    )}
  end

  def handle_event("show_new_capability_modal", _params, socket) do
    capability_changeset = Capability.changeset(%Capability{}, %{})
    {:noreply, assign(socket,
      show_capability_modal: true,
      form_mode: :new_capability,
      selected_capability: nil,
      capability_changeset: capability_changeset
    )}
  end

  def handle_event("show_edit_capability_modal", %{"id" => id}, socket) do
    capability = Repo.get(Capability, id)
    capability_changeset = Capability.changeset(capability, %{
      name: capability.name,
      description: capability.description
    })
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

  def handle_event("save_role", %{"role" => role_params} = params, socket) do
    capability_ids = params["capability_ids"] || %{}

    case socket.assigns.form_mode do
      :new_role ->
        # Create role without capabilities first
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
            # Parse the capability IDs (Phoenix sends them as a map with string keys)
            capability_ids = capability_ids
                           |> Enum.filter(fn {_k, v} -> v == "true" end)
                           |> Enum.map(fn {k, _v} -> String.to_integer(k) end)

            # Update role with both details and capabilities
            case Role.update_role_with_capabilities(role, role_params, capability_ids) do
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

  defp refresh_roles(_socket) do
    roles_query = from r in Role, order_by: r.name, preload: [:capabilities]
    Repo.all(roles_query)
  end
end
