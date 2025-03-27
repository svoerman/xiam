defmodule XIAMWeb.Components.UI do
  @moduledoc """
  A collection of UI components styled with shadcn UI.

  This module provides easy access to all shadcn UI components through a single import.

  ## Usage

  Import this module in your LiveView or component modules:

      import XIAMWeb.Components.UI

  Then use the components in your templates:

      <.button>Click me</.button>

      <.card>
        <.card_header>
          <.card_title>Title</.card_title>
          <.card_description>Description</.card_description>
        </.card_header>
        <.card_content>Content</.card_content>
      </.card>
  """

  defmacro __using__(_) do
    quote do
      import XIAMWeb.Components.UI.Alert
      import XIAMWeb.Components.UI.Button
      import XIAMWeb.Components.UI.Card
      import XIAMWeb.Components.UI.Dropdown
      import XIAMWeb.Components.UI.Input
      import XIAMWeb.Components.UI.Label
      import XIAMWeb.Components.UI.Modal
      import XIAMWeb.Components.UI.ThemeToggle
    end
  end

  # Note: The imports below are not used in this module, but they're kept here for documentation.
  # Components are imported via the __using__ macro above when used in other modules.
  #
  # import XIAMWeb.Components.UI.Alert
  # import XIAMWeb.Components.UI.Button
  # import XIAMWeb.Components.UI.Card
  # import XIAMWeb.Components.UI.Dropdown
  # import XIAMWeb.Components.UI.Input
  # import XIAMWeb.Components.UI.Label
  # import XIAMWeb.Components.UI.ThemeToggle
end
