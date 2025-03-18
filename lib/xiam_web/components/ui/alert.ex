defmodule XIAMWeb.Components.UI.Alert do
  @moduledoc """
  Alert component styled with shadcn UI.
  
  This component provides a styled alert with various variants.
  
  ## Examples
  
      <.alert>
        <.alert_title>Note</.alert_title>
        <.alert_description>This is a default alert.</.alert_description>
      </.alert>
      
      <.alert variant="destructive">
        <.alert_title>Error</.alert_title>
        <.alert_description>Your session has expired.</.alert_description>
      </.alert>
  """
  use Phoenix.Component

  @doc """
  Renders an alert with shadcn UI styling.
  
  ## Attributes
  
  * `variant` - The alert variant: "default", "destructive"
  * `class` - Additional classes to add to the alert
  * `rest` - Additional HTML attributes
  
  ## Examples
  
      <.alert>Alert content</.alert>
      <.alert variant="destructive">Error alert</.alert>
  """
  attr :variant, :string, default: "default", values: ~w(default destructive)
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def alert(assigns) do
    ~H"""
    <div
      role="alert"
      class={[
        "relative w-full rounded-lg border p-4",
        variant_styles(@variant),
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  @doc """
  Renders an alert title.
  """
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def alert_title(assigns) do
    ~H"""
    <h5 class={["mb-1 font-medium leading-none tracking-tight", @class]} {@rest}>
      <%= render_slot(@inner_block) %>
    </h5>
    """
  end

  @doc """
  Renders an alert description.
  """
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def alert_description(assigns) do
    ~H"""
    <div class={["text-sm", @class]} {@rest}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  defp variant_styles("default"), do: "bg-background text-foreground"
  defp variant_styles("destructive"), do: "border-destructive/50 text-destructive dark:border-destructive"
end
