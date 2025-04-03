defmodule XIAMWeb.Components.UI.ThemeToggleTest do
  use XIAMWeb.ConnCase
  # Phoenix.Component is needed for the ~H sigil in Phoenix 1.7+
  # but we can suppress the warning if we're not using it directly
  # import Phoenix.Component
  import Phoenix.LiveViewTest

  describe "theme_toggle component" do
    test "renders with default attributes" do
      html = render_component(&XIAMWeb.Components.UI.ThemeToggle.theme_toggle/1, %{})
      
      # Basic structure checks
      assert html =~ ~s(class="theme-toggle ") # Note the space at the end
      assert html =~ ~s(id="theme-toggle")
      assert html =~ ~s(phx-hook="ThemeToggle")
      
      # Button should exist with correct attributes
      assert html =~ ~s(aria-label="Toggle theme")
      
      # Both icons should be present
      assert html =~ ~s(id="theme-toggle-sun-icon")
      assert html =~ ~s(id="theme-toggle-moon-icon")
      
      # Sun icon should be visible by default (light theme)
      assert html =~ ~s(rotate-0 scale-100 transition-all dark:-rotate-90 dark:scale-0)
      
      # Moon icon should be hidden by default (light theme)
      assert html =~ ~s(rotate-90 scale-0 transition-all dark:rotate-0 dark:scale-100)
    end
    
    test "renders with custom class" do
      html = render_component(&XIAMWeb.Components.UI.ThemeToggle.theme_toggle/1, %{class: "custom-class"})
      
      # Should include both default and custom classes
      assert html =~ ~s(class="theme-toggle custom-class")
    end
    
    test "has both light and dark theme icons" do
      html = render_component(&XIAMWeb.Components.UI.ThemeToggle.theme_toggle/1, %{})
      
      # Sun icon for light theme
      assert html =~ "theme-toggle-sun-icon"
      assert html =~ "rotate-0 scale-100" # Visible in light mode
      assert html =~ "dark:-rotate-90 dark:scale-0" # Hidden in dark mode
      
      # Moon icon for dark theme
      assert html =~ "theme-toggle-moon-icon"
      assert html =~ "rotate-90 scale-0" # Hidden in light mode
      assert html =~ "dark:rotate-0 dark:scale-100" # Visible in dark mode
    end
    
    test "includes accessibility attributes" do
      html = render_component(&XIAMWeb.Components.UI.ThemeToggle.theme_toggle/1, %{})
      
      # Should have aria-label for accessibility
      assert html =~ ~s(aria-label="Toggle theme")
    end
    
    test "renders button with hover and focus styles" do
      html = render_component(&XIAMWeb.Components.UI.ThemeToggle.theme_toggle/1, %{})
      
      # Should include hover state styling
      assert html =~ "hover:bg-accent"
      assert html =~ "hover:text-accent-foreground"
      
      # Should include focus state styling
      assert html =~ "focus-visible:outline-none"
      assert html =~ "focus-visible:ring-2"
      
      # Should include disabled state styling
      assert html =~ "disabled:pointer-events-none"
      assert html =~ "disabled:opacity-50"
    end
  end
end