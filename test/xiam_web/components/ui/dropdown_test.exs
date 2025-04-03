defmodule XIAMWeb.Components.UI.DropdownTest do
  use ExUnit.Case, async: true
  
  import Phoenix.Component
  import Phoenix.LiveViewTest
  
  alias XIAMWeb.Components.UI.Dropdown
  
  describe "dropdown/1" do
    test "renders dropdown with trigger and content" do
      assigns = %{}
      html = 
        rendered_to_string(~H"""
        <.dropdown id="test-dropdown">
          <:trigger>
            <button>Click me</button>
          </:trigger>
          <:content>
            <p>Dropdown content</p>
          </:content>
        </.dropdown>
        """)
      
      # Test container
      assert html =~ ~r/id="test-dropdown-container"/
      
      # Test trigger
      assert html =~ ~r/id="test-dropdown-trigger"/
      assert html =~ ~r/phx-click=/
      assert html =~ ~r/phx-click-away=/
      assert html =~ "Click me"
      
      # Test content
      assert html =~ ~r/id="test-dropdown-content"/
      assert html =~ "data-hidden"
      assert html =~ "Dropdown content"
    end
    
    test "renders dropdown with custom class" do
      assigns = %{}
      html = 
        rendered_to_string(~H"""
        <.dropdown id="test-dropdown" class="custom-class">
          <:trigger>Button</:trigger>
          <:content>Content</:content>
        </.dropdown>
        """)
      
      assert html =~ ~r/class="relative custom-class"/
    end
  end
  
  describe "dropdown_item/1" do
    test "renders dropdown item with content" do
      assigns = %{}
      html = 
        rendered_to_string(~H"""
        <.dropdown_item>
          Item text
        </.dropdown_item>
        """)
      
      assert html =~ "Item text"
      assert html =~ "cursor-pointer"
      assert html =~ "select-none"
    end
    
    test "renders disabled dropdown item" do
      assigns = %{}
      html = 
        rendered_to_string(~H"""
        <.dropdown_item disabled>
          Disabled item
        </.dropdown_item>
        """)
      
      assert html =~ "Disabled item"
      assert html =~ ~r/data-disabled/
    end
    
    test "renders dropdown item with custom class" do
      assigns = %{}
      html = 
        rendered_to_string(~H"""
        <.dropdown_item class="custom-item-class">
          Item with custom class
        </.dropdown_item>
        """)
      
      assert html =~ "Item with custom class"
      assert html =~ "custom-item-class"
    end
    
    test "renders dropdown item with additional attributes" do
      assigns = %{}
      html = 
        rendered_to_string(~H"""
        <.dropdown_item phx-click="handle_click" data-test="test-item">
          Item with attributes
        </.dropdown_item>
        """)
      
      assert html =~ "Item with attributes"
      assert html =~ ~r/phx-click="handle_click"/
      assert html =~ ~r/data-test="test-item"/
    end
  end
  
  describe "dropdown_separator/1" do
    test "renders dropdown separator" do
      assigns = %{}
      html = 
        rendered_to_string(~H"""
        <.dropdown_separator />
        """)
      
      assert html =~ "h-px"
      assert html =~ "bg-border"
    end
    
    test "renders dropdown separator with custom class" do
      assigns = %{}
      html = 
        rendered_to_string(~H"""
        <.dropdown_separator class="custom-separator" />
        """)
      
      assert html =~ "h-px"
      assert html =~ "custom-separator"
    end
  end
  
  # Import the function components for use with ~H
  defp dropdown(assigns), do: Dropdown.dropdown(assigns)
  defp dropdown_item(assigns), do: Dropdown.dropdown_item(assigns)
  defp dropdown_separator(assigns), do: Dropdown.dropdown_separator(assigns)
end