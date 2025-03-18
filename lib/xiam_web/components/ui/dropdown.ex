defmodule XIAMWeb.Components.UI.Dropdown do
  @moduledoc """
  Dropdown menu component styled with shadcn UI.
  
  This component provides a dropdown menu with trigger and content.
  It uses Phoenix JS commands for interactivity.
  
  ## Examples
  
      <.dropdown id="user-menu">
        <:trigger>
          <.button variant="ghost">Menu</.button>
        </:trigger>
        <:content>
          <.dropdown_item>Profile</.dropdown_item>
          <.dropdown_item>Settings</.dropdown_item>
          <.dropdown_separator />
          <.dropdown_item>Logout</.dropdown_item>
        </:content>
      </.dropdown>
  """
  use Phoenix.Component
  alias Phoenix.LiveView.JS
  
  @doc """
  Renders a dropdown menu.
  
  ## Attributes
  
  * `id` - Required unique identifier for the dropdown
  * `class` - Additional classes for the dropdown container
  
  ## Slots
  
  * `:trigger` - The element that triggers the dropdown
  * `:content` - The dropdown content
  
  ## Examples
  
      <.dropdown id="user-menu">
        <:trigger>
          <.button>Menu</.button>
        </:trigger>
        <:content>
          <.dropdown_item>Profile</.dropdown_item>
          <.dropdown_item>Settings</.dropdown_item>
        </:content>
      </.dropdown>
  """
  attr :id, :string, required: true
  attr :class, :string, default: nil
  
  slot :trigger, required: true
  slot :content, required: true
  
  def dropdown(assigns) do
    ~H"""
    <div class={["relative", @class]} id={@id <> "-container"}>
      <div 
        id={@id <> "-trigger"}
        phx-click={JS.toggle(to: "#" <> @id <> "-content")}
        phx-click-away={JS.hide(to: "#" <> @id <> "-content")}
      >
        <%= render_slot(@trigger) %>
      </div>
      
      <div
        id={@id <> "-content"}
        class="absolute z-50 min-w-[8rem] overflow-hidden rounded-md border bg-popover p-1 text-popover-foreground shadow-lg data-[hidden]:hidden animate-accordion-down"
        data-hidden
      >
        <%= render_slot(@content) %>
      </div>
    </div>
    """
  end
  
  @doc """
  Renders a dropdown menu item.
  """
  attr :class, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true
  
  def dropdown_item(assigns) do
    ~H"""
    <div 
      class={[
        "relative flex cursor-pointer select-none items-center rounded-sm px-2 py-1.5 text-sm outline-none transition-colors",
        "focus:bg-accent focus:text-accent-foreground",
        "hover:bg-accent hover:text-accent-foreground",
        "data-[disabled]:pointer-events-none data-[disabled]:opacity-50",
        @class
      ]}
      data-disabled={@disabled}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </div>
    """
  end
  
  @doc """
  Renders a separator in the dropdown menu.
  """
  attr :class, :string, default: nil
  
  def dropdown_separator(assigns) do
    ~H"""
    <div class={["-mx-1 my-1 h-px bg-border", @class]}></div>
    """
  end
end
