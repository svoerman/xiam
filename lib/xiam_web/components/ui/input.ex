defmodule XIAMWeb.Components.UI.Input do
  @moduledoc """
  Input component styled with shadcn UI.
  
  This component provides a styled input field with various types and options.
  
  ## Examples
  
      <.input type="text" placeholder="Username" />
      <.input type="email" value={@email} />
      <.input type="password" name="password" required />
  """
  use Phoenix.Component

  @doc """
  Renders an input with shadcn UI styling.
  
  ## Attributes
  
  * `type` - The input type: "text", "email", "password", etc.
  * `class` - Additional classes to add to the input
  * `rest` - Additional HTML attributes
  
  ## Examples
  
      <.input type="text" name="username" />
      <.input type="email" placeholder="Enter email" required />
  """
  attr :id, :string, default: nil
  attr :name, :string, default: nil
  attr :type, :string, default: "text"
  attr :value, :any, default: nil
  attr :class, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :required, :boolean, default: false
  attr :placeholder, :string, default: nil
  attr :rest, :global, include: ~w(autocomplete autofocus max maxlength min minlength pattern readonly step)

  def input(assigns) do
    ~H"""
    <input
      id={@id}
      name={@name}
      type={@type}
      value={@value}
      placeholder={@placeholder}
      disabled={@disabled}
      required={@required}
      class={[
        "flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background",
        "file:border-0 file:bg-transparent file:text-sm file:font-medium",
        "placeholder:text-muted-foreground",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
        "disabled:cursor-not-allowed disabled:opacity-50",
        @class
      ]}
      {@rest}
    />
    """
  end
end
