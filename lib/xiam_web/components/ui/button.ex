defmodule XIAMWeb.Components.UI.Button do
  @moduledoc """
  Button component styled with shadcn UI.
  This component provides a styled button with various variants and sizes.
  
  ## Examples
  
      <.button>Default Button</.button>
      <.button variant="destructive">Delete</.button>
      <.button variant="outline" size="sm">Small Outline</.button>
      <.button variant="ghost" class="extra-class">Ghost</.button>
  """
  use Phoenix.Component

  @doc """
  Renders a button with shadcn UI styling.
  
  ## Attributes
  
  * `variant` - The button variant: "default", "destructive", "outline", "secondary", "ghost", "link"
  * `size` - The button size: "default", "sm", "lg", "icon"
  * `class` - Additional classes to add to the button
  * `rest` - Additional HTML attributes to add to the button element
  
  ## Examples
  
      <.button>Click me</.button>
      <.button variant="destructive">Delete</.button>
  """
  attr :variant, :string, default: "default", values: ~w(default destructive outline secondary ghost link)
  attr :size, :string, default: "default", values: ~w(default sm lg icon)
  attr :class, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :type, :string, default: "button"
  attr :rest, :global, include: ~w(form name value)
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      disabled={@disabled}
      class={[
        "inline-flex items-center justify-center whitespace-nowrap rounded-md font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50",
        get_variant_class(@variant),
        get_size_class(@size),
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  defp get_variant_class("default"), do: "bg-primary text-primary-foreground hover:bg-primary/90"
  defp get_variant_class("destructive"), do: "bg-destructive text-destructive-foreground hover:bg-destructive/90"
  defp get_variant_class("outline"), do: "border border-input bg-background hover:bg-accent hover:text-accent-foreground"
  defp get_variant_class("secondary"), do: "bg-secondary text-secondary-foreground hover:bg-secondary/80"
  defp get_variant_class("ghost"), do: "hover:bg-accent hover:text-accent-foreground"
  defp get_variant_class("link"), do: "text-primary underline-offset-4 hover:underline"

  defp get_size_class("default"), do: "h-10 px-4 py-2"
  defp get_size_class("sm"), do: "h-9 rounded-md px-3"
  defp get_size_class("lg"), do: "h-11 rounded-md px-8"
  defp get_size_class("icon"), do: "h-10 w-10"
end
