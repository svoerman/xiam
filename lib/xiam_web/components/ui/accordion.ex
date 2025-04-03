# Based on shadcn/ui Accordion - https://ui.shadcn.com/docs/components/accordion
# Requires JavaScript (e.g., Alpine.js or custom hooks) for interaction.

defmodule XIAMWeb.Components.UI.Accordion do
  use Phoenix.Component
  import XIAMWeb.CoreComponents # Import CoreComponents to make <.icon> available

  attr :type, :string, default: "single", values: ["single", "multiple"], doc: "Determines if multiple items can be open at once."
  attr :collapsible, :boolean, default: false, doc: "Allows all items to be closed when type is single."
  attr :class, :string, default: nil, doc: "CSS class for the accordion container."
  slot :inner_block, required: true

  @doc """
  Renders the accordion container.

  Accepts `type` ("single" or "multiple", defaults to "single") and
  `collapsible` (boolean, defaults to false for type="single") attributes
  which are typically used by the accompanying JavaScript to control behavior.
  Other HTML attributes are passed to the underlying div.

  ## Examples

      <.accordion type="single" collapsible class="w-full">
        <.accordion_item value="item-1">
          <.accordion_trigger>Is it accessible?</.accordion_trigger>
          <.accordion_content>
            Yes. It adheres to the WAI-ARIA design pattern.
          </.accordion_content>
        </.accordion_item>
      </.accordion>
  """
  def accordion(assigns) do
    ~H"""
    <div
      class={@class}
      # Pass other attributes, excluding handled ones
      {assigns_to_attributes(assigns, [:type, :collapsible, :class, :inner_block])}
    >
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  @doc """
  Renders an accordion item.

  Requires a unique `value` assign for identification by the controlling JavaScript.
  Other HTML attributes are passed to the underlying div.

  ## Examples

      <.accordion_item value="item-1">
        ...
      </.accordion_item>
  """
  attr :value, :string, required: true
  attr :class, :string, default: nil, doc: "CSS class for the accordion item."
  slot :inner_block, required: true

  def accordion_item(assigns) do
    ~H"""
    <div
      class={["border-b", @class]}
      # Exclude value, class, and inner_block from being passed as HTML attributes
      {assigns_to_attributes(assigns, [:value, :class, :inner_block])}
    >
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  @doc """
  Renders the trigger button for an accordion item.

  Contains the header content of the accordion item.
  JavaScript usually targets this element to toggle visibility.
  Applies ARIA attributes for accessibility.
  Other HTML attributes are passed to the underlying button.

  ## Examples

      <.accordion_trigger>Is it accessible?</.accordion_trigger>
  """
  attr :class, :string, default: nil, doc: "CSS class for the accordion trigger button."
  attr :value, :string, required: true, doc: "Unique value for the accordion item, used for event handling."
  attr :state, :string, default: "closed", values: ["open", "closed"], doc: "Current state (open/closed), managed by parent LiveView."
  slot :inner_block, required: true

  def accordion_trigger(assigns) do
    ~H"""
    <h3 class="flex">
      <%!-- Changed from button to div to avoid default value attribute conflicts --%>
      <div
        role="button"             # Accessibility
        tabindex="0"             # Accessibility - make it focusable
        phx-click="toggle_accordion"
        phx-value-item={@value}
        aria-expanded={@state == "open"}
        data-state={@state}
        class={["flex flex-1 items-center justify-between py-4 font-medium transition-all hover:underline cursor-pointer [&[data-state=open]>svg]:rotate-180", @class]}
        {assigns_to_attributes(assigns, [:class, :value, :state, :inner_block])}
      >
        <span class="flex-1 text-left">
          <%= render_slot(@inner_block) %>
        </span>
        <.icon name="hero-chevron-down" class="h-4 w-4 shrink-0 transition-transform duration-200" />
      </div>
    </h3>
    """
  end

  @doc """
  Renders the collapsible content area for an accordion item.

  Contains the detailed content. Its visibility is typically controlled by JavaScript
  based on the accordion item's state.
  Other HTML attributes are passed to the underlying div.

  ## Examples

      <.accordion_content>
        Yes. It adheres to the WAI-ARIA design pattern.
      </.accordion_content>
  """
  attr :class, :string, default: nil, doc: "CSS class for the accordion content area."
  attr :state, :string, default: "closed", values: ["open", "closed"], doc: "Current state (open/closed), managed by parent LiveView."
  slot :inner_block, required: true

  def accordion_content(assigns) do
    ~H"""
    <%!-- Note: The id and data-state attributes are typically managed by JS. --%>
    <%!-- Note: Rendering is controlled by parent `if`. Removed potentially problematic classes. --%>
    <div
      data-state={@state}
      class={["text-sm", @class]}
      {assigns_to_attributes(assigns, [:class, :state, :inner_block])}
    >
      <div class="pb-4 pt-0"> <%!-- Ensure basic padding for content --%>
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  # Basic Heroicon component (assuming it's available/defined elsewhere or inline)
  # If not, this needs to be adjusted or imported properly.
  # Example definition if needed:
  # defp icon(%{name: name} = assigns)
  #   assigns = assign_new(assigns, :class, fn -> "w-4 h-4" end)
  #   ~H"""
  #   <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class={@class}>
  #     <%= render_icon_path(name) %>
  #   </svg>
  #   """
  # end
  # defp render_icon_path("hero-chevron-down") do
  #   ~H"""<path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5" />"""
  # end
  # Add other icon paths as needed...
end
