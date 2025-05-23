defmodule XIAMWeb.HeaderComponent do
  use XIAMWeb, :html

  # Function component for universal header
  def main_header(assigns) do
    current_user =
      cond do
        Map.has_key?(assigns, :current_user) && assigns.current_user -> assigns.current_user
        Map.has_key?(assigns, :conn) && assigns.conn -> Pow.Plug.current_user(assigns.conn)
        true -> nil
      end

    assigns = assign(assigns, :current_user, current_user)

    ~H"""
    <header class="px-4 sm:px-6 lg:px-8">
      <div class="flex items-center justify-between border-b border-border py-3 text-sm">
        <div class="flex items-center gap-4">
          <a href="/">
            <!-- Light mode logo -->
            <img src={~p"/images/logo_for_light_bg.png"} width="96" class="block dark:hidden" alt="XIAM Logo" />
            <!-- Dark mode logo -->
            <img src={~p"/images/logo_for_dark_bg.png"} width="96" class="hidden dark:block" alt="XIAM Logo" />
          </a>
        </div>
        <div class="flex items-center gap-4">
          <%= if @current_user do %>
            <div class="flex items-center gap-4">
              <.link href={~p"/account"} class="text-sm font-medium text-foreground hover:text-primary transition-colors">
                Account Settings
              </.link>
              <.link href={~p"/session"} method="delete" class="text-sm font-medium text-foreground hover:text-primary transition-colors">
                Sign Out
              </.link>
            </div>
          <% else %>
            <a href="/session/new" class="text-sm font-medium text-foreground hover:text-primary transition-colors">
              Sign In
            </a>
          <% end %>
          <button
            id="theme-toggle-btn"
            class="inline-flex h-10 w-10 items-center justify-center rounded-md border border-input bg-background p-2 text-sm font-medium ring-offset-background transition-colors hover:bg-accent hover:text-accent-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 relative"
            aria-label="Toggle theme"
            onclick="toggleTheme()"
          >
            <svg
              id="theme-toggle-sun-icon"
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
              id="theme-toggle-moon-icon"
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
      </div>
    </header>
    """
  end
end
