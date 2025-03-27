defmodule XIAMWeb.Components.UI.Modal do
  @moduledoc """
  Modal component styled with shadcn UI.

  This component provides a styled modal dialog with backdrop and animations.

  ## Examples

      <.modal show={@show_modal} on_close={JS.push("close_modal")}>
        <:title>Modal Title</:title>
        <:content>
          Modal content goes here
        </:content>
        <:footer>
          <.button variant="outline" phx-click="close_modal">Cancel</.button>
          <.button>Save</.button>
        </:footer>
      </.modal>
  """
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  @doc """
  Renders a modal dialog with shadcn UI styling.

  ## Attributes

  * `show` - Whether the modal is visible
  * `on_close` - JS command to execute when closing the modal
  * `class` - Additional classes for the modal content

  ## Slots

  * `:title` - The modal title
  * `:content` - The modal content
  * `:footer` - The modal footer

  ## Examples

      <.modal show={@show_modal} on_close={JS.push("close_modal")}>
        <:title>Edit User</:title>
        <:content>Form goes here</:content>
        <:footer>
          <.button>Save</.button>
        </:footer>
      </.modal>
  """
  attr :id, :string, default: "modal"
  attr :show, :boolean, default: false
  attr :on_close, JS, default: %JS{}
  attr :class, :string, default: nil

  slot :title, required: true
  slot :content, required: true
  slot :footer

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      class="relative z-50 hidden"
      data-modal
    >
      <div
        id={"#{@id}-bg"}
        class="fixed inset-0 bg-background/80 backdrop-blur-sm transition-opacity"
        aria-hidden="true"
      />

      <div class="fixed inset-0 overflow-y-auto">
        <div class="flex min-h-full items-center justify-center p-4 sm:p-6">
          <div
            id={"#{@id}-container"}
            phx-click-away={@on_close}
            class="relative hidden w-full max-w-lg scale-100 rounded-lg border bg-card p-6 shadow-lg duration-200 sm:p-8"
          >
            <div class="absolute right-4 top-4">
              <button
                phx-click={@on_close}
                type="button"
                class="-m-3 flex h-8 w-8 items-center justify-center rounded-md transition-colors hover:text-muted-foreground"
                aria-label="Close"
              >
                <svg class="h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <div id={"#{@id}-content"} class={["space-y-4", @class]}>
              <div class="space-y-1.5">
                <h2 class="text-lg font-semibold leading-none tracking-tight">
                  <%= render_slot(@title) %>
                </h2>
              </div>

              <div class="py-4">
                <%= render_slot(@content) %>
              </div>

              <%= if @footer != [] do %>
                <div class="flex justify-end gap-2">
                  <%= render_slot(@footer) %>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Show modal with animation
  defp show_modal(id) when is_binary(id) do
    %JS{}
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-container")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  # Hide modal with animation
  defp hide_modal(id) when is_binary(id) do
    %JS{}
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  # Show element with scale animation
  defp show(js, selector) when is_binary(selector) do
    JS.show(js,
      to: selector,
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  # Hide element with scale animation
  defp hide(js, selector) when is_binary(selector) do
    JS.hide(js,
      to: selector,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end
end
