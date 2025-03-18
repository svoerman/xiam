defmodule XIAMWeb.Components.UI.Label do
  @moduledoc """
  Label component styled with shadcn UI.
  
  This component provides a styled label for form inputs.
  
  ## Examples
  
      <.label for="email">Email</.label>
      <.input id="email" type="email" />
  """
  use Phoenix.Component

  @doc """
  Renders a label with shadcn UI styling.
  
  ## Attributes
  
  * `for` - The ID of the associated form control
  * `class` - Additional classes to add to the label
  * `rest` - Additional HTML attributes
  
  ## Examples
  
      <.label for="username">Username</.label>
  """
  attr :for, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label
      for={@for}
      class={[
        "text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70",
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </label>
    """
  end
end
