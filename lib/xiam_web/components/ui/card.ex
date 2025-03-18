defmodule XIAMWeb.Components.UI.Card do
  @moduledoc """
  Card components styled with shadcn UI.
  
  These components provide a set of building blocks for creating card-based interfaces.
  
  ## Examples
  
      <.card>
        <.card_header>
          <.card_title>Card Title</.card_title>
          <.card_description>Card Description</.card_description>
        </.card_header>
        <.card_content>
          Content goes here
        </.card_content>
        <.card_footer>
          <.button>Action</.button>
        </.card_footer>
      </.card>
  """
  use Phoenix.Component
  
  @doc """
  Renders a card container.
  
  ## Attributes
  
  * `class` - Additional classes to add to the card
  * `rest` - Additional HTML attributes
  
  ## Examples
  
      <.card>Card content</.card>
  """
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div class={["rounded-lg border bg-card text-card-foreground shadow-sm", @class]} {@rest}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  @doc """
  Renders a card header.
  """
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def card_header(assigns) do
    ~H"""
    <div class={["flex flex-col space-y-1.5 p-6", @class]} {@rest}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  @doc """
  Renders a card title.
  """
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def card_title(assigns) do
    ~H"""
    <h3 class={["text-2xl font-semibold leading-none tracking-tight", @class]} {@rest}>
      <%= render_slot(@inner_block) %>
    </h3>
    """
  end

  @doc """
  Renders a card description.
  """
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def card_description(assigns) do
    ~H"""
    <p class={["text-sm text-muted-foreground", @class]} {@rest}>
      <%= render_slot(@inner_block) %>
    </p>
    """
  end

  @doc """
  Renders a card content section.
  """
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def card_content(assigns) do
    ~H"""
    <div class={["p-6 pt-0", @class]} {@rest}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  @doc """
  Renders a card footer.
  """
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def card_footer(assigns) do
    ~H"""
    <div class={["flex items-center p-6 pt-0", @class]} {@rest}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end
end
