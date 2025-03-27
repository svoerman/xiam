defmodule XIAMWeb.Pow.Components do
  use Phoenix.Component

  # Import both core components and UI components
  import XIAMWeb.CoreComponents
  import XIAMWeb.Components.UI

  # Re-export the button component from core components for Pow templates
  def pow_button(assigns) do
    ~H"""
    <.button type={@type} class={@class} {@rest}>
      <%= render_slot(@inner_block) %>
    </.button>
    """
  end
end
