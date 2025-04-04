defmodule XIAMWeb.Components.UI.ThemeToggleTest do
  use XIAMWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias XIAMWeb.Components.UI.ThemeToggle

  describe "theme_toggle component" do
    test "renders with default attributes" do
      html = render_component(&ThemeToggle.theme_toggle/1, %{})

      assert html =~ "class=\"theme-toggle \""
      assert html =~ "phx-hook=\"ThemeToggle\""
      assert html =~ "aria-label=\"Toggle theme\""
    end

    test "renders with custom class" do
      html = render_component(&ThemeToggle.theme_toggle/1, %{class: "custom-class"})

      assert html =~ "class=\"theme-toggle custom-class\""
    end

    test "renders with custom id" do
      html = render_component(&ThemeToggle.theme_toggle/1, %{id: "custom-toggle"})

      assert html =~ ~s(id="custom-toggle")
    end

    test "has both light and dark theme icons" do
      html = render_component(&ThemeToggle.theme_toggle/1, %{})

      assert html =~ "-sun-icon"
      assert html =~ "-moon-icon"
      assert html =~ "dark:-rotate-90"
      assert html =~ "dark:rotate-0"
    end

    test "includes accessibility attributes" do
      html = render_component(&ThemeToggle.theme_toggle/1, %{})

      assert html =~ ~s(aria-label="Toggle theme")
    end

    test "renders button with hover and focus styles" do
      html = render_component(&ThemeToggle.theme_toggle/1, %{})

      assert html =~ "hover:bg-accent"
      assert html =~ "hover:text-accent-foreground"
      assert html =~ "focus-visible:outline-none"
      assert html =~ "focus-visible:ring-2"
      assert html =~ "disabled:pointer-events-none"
      assert html =~ "disabled:opacity-50"
    end
  end
end
