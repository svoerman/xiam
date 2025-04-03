defmodule XIAMWeb.Admin.EntityAccessLive do
  use XIAMWeb, :live_view

  import XIAMWeb.Components.UI.Button
  import XIAMWeb.Components.UI.Modal
  import XIAMWeb.CoreComponents, except: [button: 1, modal: 1]
  import XIAMWeb.Components.UI

  alias Xiam.Rbac.AccessControl
  alias Xiam.Rbac.EntityAccess
  alias Xiam.Rbac.Role
  alias XIAM.Repo

  @impl true
  def mount(_params, _session, socket) do
    access_list = AccessControl.list_entity_access() |> Repo.preload([:user, :role])
    changeset = EntityAccess.changeset(%EntityAccess{}, %{})
    roles = Repo.all(Role)

    socket = assign(socket,
      page_title: "Entity Access",
      access_list: access_list,
      selected_access: nil,
      access_changeset: changeset,
      form_mode: nil,
      show_modal: false,
      roles: roles
    )

    {:ok, socket}
  end

  @impl true
  def handle_event("show_new_access_modal", _params, socket) do
    access_changeset = EntityAccess.changeset(%EntityAccess{}, %{})
    {:noreply, assign(socket,
      show_modal: true,
      form_mode: :new_access,
      selected_access: nil,
      access_changeset: access_changeset
    )}
  end

  def handle_event("show_edit_access_modal", %{"id" => id}, socket) do
    case AccessControl.get_entity_access(id) |> Repo.preload(:role) do
      nil ->
        {:noreply, socket |> put_flash(:error, "Access entry not found")}
      access ->
        access_changeset = EntityAccess.changeset(access, %{
          id: access.id,
          user_id: access.user_id,
          entity_type: access.entity_type,
          entity_id: access.entity_id,
          role_id: access.role_id
        })
        {:noreply, assign(socket,
          show_modal: true,
          form_mode: :edit_access,
          selected_access: access,
          access_changeset: access_changeset
        )}
    end
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket,
      show_modal: false,
      form_mode: nil,
      selected_access: nil,
      access_changeset: EntityAccess.changeset(%EntityAccess{}, %{})
    )}
  end

  def handle_event("save_access", %{"entity_access" => access_params}, socket) do
    case socket.assigns.form_mode do
      :new_access ->
        case AccessControl.set_user_access(access_params) do
          {:ok, _access} ->
            access_list = AccessControl.list_entity_access() |> Repo.preload([:user, :role])
            access_changeset = EntityAccess.changeset(%EntityAccess{}, %{})

            {:noreply, socket
              |> assign(access_list: access_list, show_modal: false, access_changeset: access_changeset)
              |> put_flash(:info, "Access created successfully")}

          {:error, changeset} ->
            {:noreply, assign(socket, access_changeset: changeset)}
        end

      :edit_access ->
        case socket.assigns.selected_access do
          nil ->
            {:noreply, socket |> put_flash(:error, "No access entry selected")}
          _access ->
            case AccessControl.set_user_access(access_params) do
              {:ok, _access} ->
                access_list = AccessControl.list_entity_access() |> Repo.preload([:user, :role])
                access_changeset = EntityAccess.changeset(%EntityAccess{}, %{})

                {:noreply, socket
                  |> assign(access_list: access_list, show_modal: false, access_changeset: access_changeset)
                  |> put_flash(:info, "Access updated successfully")}

              {:error, changeset} ->
                {:noreply, assign(socket, access_changeset: changeset)}
            end
        end

      _other ->
        {:noreply, socket |> put_flash(:error, "Invalid form mode")}
    end
  end

  def handle_event("delete_access", %{"id" => id}, socket) do
    case AccessControl.get_entity_access(id) do
      nil ->
        {:noreply, socket |> put_flash(:error, "Access entry not found")}
      access ->
        case AccessControl.delete_entity_access(access) do
          {:ok, _} ->
            access_list = AccessControl.list_entity_access() |> Repo.preload([:user, :role])
            {:noreply, socket
              |> assign(access_list: access_list)
              |> put_flash(:info, "Access deleted successfully")}

          {:error, _changeset} ->
            {:noreply, socket |> put_flash(:error, "Failed to delete access entry")}
        end
    end
  end
end
