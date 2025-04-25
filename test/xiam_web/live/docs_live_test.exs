defmodule XIAMWeb.DocsLiveTest do
  use XIAMWeb.ConnCase
  import Phoenix.LiveViewTest

  test "mounts successfully with documentation sections", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/docs")

    # Verify page loads with expected title
    assert html =~ "XIAM Documentation"

    # Verify documentation sections are rendered
    assert has_element?(view, "h1", "XIAM Documentation")
    assert has_element?(view, "p", "Installation and Usage Guide")
  end

  test "contains introduction section", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/docs")

    # Check for Introduction section
    assert has_element?(view, "#introduction", "Introduction")
    assert has_element?(view, "p", "XIAM is a platform built with Elixir and Phoenix")
  end

  test "contains installation section with accordion", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/docs")

    # Check installation section exists
    assert has_element?(view, "#installation", "Installation")

    # Check accordion items are present
    assert has_element?(view, "[role='button']", "Prerequisites")
    assert has_element?(view, "[role='button']", "Setup Steps")
  end

  test "contains usage information section", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/docs")

    # Check usage section exists
    assert has_element?(view, "#usage", "Usage")
    assert has_element?(view, "#core-concepts", "Core Concepts")
    assert has_element?(view, "#web-interface", "Web Interface")
    assert has_element?(view, "#api", "API")
  end

  test "handles accordion toggle events", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/docs")

    # Initial state should have all accordion items closed
    refute view |> element("[phx-value-item='item-1'][data-state='open']") |> has_element?()

    # Test toggle_accordion event directly by sending it
    view
    |> element("[phx-value-item='item-1']")
    |> render_click()

    # After sending the event, check if the component reacts
    assert view |> render() =~ "Elixir (~&gt; 1.15)"
  end

  test "back link is present", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/docs")

    # Check for back link
    assert has_element?(view, "a", "← Back")
  end

  test "contains API documentation link", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/docs")

    # Check for API docs link
    assert has_element?(view, "a[href='/api/docs']", "/api/docs")
  end

  test "shows admin dashboard section", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/docs")

    # Check for admin dashboard section
    assert has_element?(view, "#admin-dashboard", "Admin Dashboard")
    assert has_element?(view, "h3", "User Management")
    assert has_element?(view, "h3", "Roles & Capabilities")
    assert has_element?(view, "h3", "GDPR Compliance")
  end

  test "has correct page title", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/docs")
    # Assert for the current title format with suffix
    # Robust assertion: match title content regardless of whitespace
    assert Regex.match?(~r/<title data-default="XIAM" data-suffix=" · XIAM">\s*XIAM Documentation\s*· XIAM<\/title>/, html)
  end
end
