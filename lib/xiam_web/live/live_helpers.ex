defmodule XIAMWeb.LiveHelpers do
  @moduledoc """
  Shared helper functions for LiveView modules to reduce duplication.
  Provides utilities for modal handling, flash messages, and common UI patterns.
  """

  import Phoenix.Component
  import Phoenix.LiveView

  alias Phoenix.LiveView.JS

  @doc """
  Renders a standard modal dialog with the given content.
  """
  def render_modal(assigns) do
    ~H"""
    <div
      id={@id}
      class="fixed inset-0 z-50 flex items-center justify-center overflow-y-auto bg-gray-900/80"
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
    >
      <div
        id={"#{@id}-container"}
        class="w-full max-w-3xl max-h-screen overflow-auto bg-white rounded-lg shadow-lg p-6"
        phx-click-away={JS.dispatch("click", to: "##{@id}-close")}
        phx-window-keydown={JS.dispatch("click", to: "##{@id}-close")}
        phx-key="escape"
      >
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-xl font-semibold"><%= @title %></h2>
          <button
            id={"#{@id}-close"}
            type="button"
            class="text-gray-500 hover:text-gray-700"
            phx-click={JS.exec("data-cancel", to: "##{@id}")}
            aria-label="Close"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        </div>
        <div class="mt-4">
          <%= render_slot(@inner_block) %>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Shows a modal with the given ID.
  """
  def show_modal(id) do
    JS.add_class("opacity-100", to: "##{id}")
    |> JS.remove_class("opacity-0")
    |> JS.focus_first(to: "##{id}-container")
  end

  @doc """
  Hides a modal with the given ID.
  """
  def hide_modal(id) do
    JS.add_class("opacity-0", to: "##{id}")
    |> JS.remove_class("opacity-100")
    |> JS.hide(to: "##{id}", transition: {"ease-in duration-200", "opacity-100", "opacity-0"})
  end

  @doc """
  Displays a confirmation dialog.
  Takes the title, message, confirm/cancel labels, and confirmation function.
  """
  def confirm(js \\ %JS{}, id, title, message, confirm_label, cancel_label, confirm_action) do
    js
    |> JS.push("show_confirm", value: %{
      id: id,
      title: title,
      message: message,
      confirm_label: confirm_label,
      cancel_label: cancel_label,
      confirm_action: confirm_action
    })
  end

  @doc """
  Shows a success flash notification.
  """
  def put_success_flash(socket, message) do
    put_flash(socket, :info, message)
  end

  @doc """
  Shows an error flash notification.
  """
  def put_error_flash(socket, message) do
    put_flash(socket, :error, message)
  end

  @doc """
  Handles common CRUD operation results with appropriate flash messages.
  """
  def handle_crud_result(socket, {:ok, _result}, success_message) do
    socket
    |> put_success_flash(success_message)
    |> reset_form()
  end

  def handle_crud_result(socket, {:error, %Ecto.Changeset{} = changeset}, error_message) do
    socket
    |> put_error_flash(error_message)
    |> assign(:changeset, changeset)
  end

  def handle_crud_result(socket, {:error, _}, error_message) do
    socket
    |> put_error_flash(error_message)
  end

  @doc """
  Resets form-related assigns in a LiveView.
  """
  def reset_form(socket) do
    socket
    |> assign(changeset: nil)
    |> assign(form_mode: nil)
    |> assign(form_entity: nil)
    |> assign(show_form: false)
  end

  @doc """
  Sets up a LiveView form for creating a new entity.
  """
  def setup_new_form(socket, module, attrs \\ %{}) do
    changeset = module.changeset(struct(module), attrs)

    socket
    |> assign(changeset: changeset)
    |> assign(form_mode: :new)
    |> assign(form_entity: nil)
    |> assign(show_form: true)
  end

  @doc """
  Sets up a LiveView form for editing an existing entity.
  """
  def setup_edit_form(socket, entity, module, attrs \\ %{}) do
    changeset = module.changeset(entity, attrs)

    socket
    |> assign(changeset: changeset)
    |> assign(form_mode: :edit)
    |> assign(form_entity: entity)
    |> assign(show_form: true)
  end
end