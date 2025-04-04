defmodule XIAMWeb.Components.UI.ThemeToggle do
  @moduledoc """
  Theme toggle component for switching between light and dark modes.

  This component provides a button that toggles between light and dark themes
  using the shadcn UI theming system.

  ## Examples

      <.theme_toggle />
  """
  use Phoenix.Component

  @doc """
  Renders a theme toggle button.

  ## Attributes

  * `class` - Additional classes to add to the toggle
  * `id` - Optional ID for the toggle (unique ID is generated if not provided)

  ## Examples

      <.theme_toggle />
      <.theme_toggle class="absolute top-4 right-4" />
      <.theme_toggle id="custom-theme-toggle" />
  """
  attr :class, :string, default: ""
  attr :id, :string, default: nil

  def theme_toggle(assigns) do
    assigns = assign_new(assigns, :unique_id, fn ->
      "theme-toggle-#{:erlang.unique_integer([:positive])}"
    end)

    ~H"""
    <div class={["theme-toggle", @class]} id={@id || @unique_id} phx-hook="ThemeToggle">
      <button
        class="inline-flex h-10 w-10 items-center justify-center rounded-md border border-input bg-background p-2 text-sm font-medium ring-offset-background transition-colors hover:bg-accent hover:text-accent-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50"
        aria-label="Toggle theme"
      >
        <svg
          id={"#{@unique_id}-sun-icon"}
          class="h-5 w-5 rotate-0 scale-100 transition-all dark:-rotate-90 dark:scale-0"
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
        >
          <path
            d="M12 16C14.2091 16 16 14.2091 16 12C16 9.79086 14.2091 8 12 8C9.79086 8 8 9.79086 8 12C8 14.2091 9.79086 16 12 16Z"
            fill="currentColor"
          />
          <path
            d="M12 2V4M12 20V22M4 12H2M6.31412 6.31412L4.8999 4.8999M17.6859 6.31412L19.1001 4.8999M6.31412 17.69L4.8999 19.1042M17.6859 17.69L19.1001 19.1042M22 12H20"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>

        <svg
          id={"#{@unique_id}-moon-icon"}
          class="absolute h-5 w-5 rotate-90 scale-0 transition-all dark:rotate-0 dark:scale-100"
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
        >
          <path
            d="M21.5287 15.9294C21.3687 15.6594 20.9187 15.2394 19.7987 15.4394C19.1787 15.5494 18.5487 15.5994 17.9187 15.5694C15.5887 15.4694 13.4787 14.3994 12.0087 12.7494C10.7087 11.2994 9.90873 9.40938 9.89873 7.38938C9.89873 6.23938 10.1187 5.13938 10.5687 4.08938C11.0087 3.07938 10.6987 2.54938 10.4787 2.32938C10.2487 2.09938 9.70873 1.77938 8.64873 2.21938C4.55873 3.93938 2.02873 8.03938 2.32873 12.4294C2.62873 16.5594 5.52873 20.0894 9.36873 21.4194C10.2887 21.7394 11.2587 21.9294 12.2387 21.9694C12.4787 21.9794 12.7087 21.9894 12.9487 21.9894C16.0087 21.9894 18.8487 20.6294 20.7487 18.3494C21.4787 17.4794 21.6987 16.1994 21.5287 15.9294Z"
            fill="currentColor"
          />
        </svg>
      </button>
    </div>
    """
  end
end
