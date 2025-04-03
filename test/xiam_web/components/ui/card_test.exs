defmodule XIAMWeb.Components.UI.CardTest do
  use ExUnit.Case
  import Phoenix.LiveViewTest
  import Phoenix.Component
  alias XIAMWeb.Components.UI.Card

  setup do
    %{assigns: %{}}
  end

  describe "card component" do
    test "renders card container with content", %{assigns: assigns} do
      html = 
        rendered_to_string(~H"""
        <Card.card>Card content</Card.card>
        """)
        
      assert html =~ "Card content"
      assert html =~ "rounded-lg border bg-card"
    end

    test "renders card with custom class", %{assigns: assigns} do
      html = 
        rendered_to_string(~H"""
        <Card.card class="custom-card-class">Card content</Card.card>
        """)
        
      assert html =~ "custom-card-class"
    end

    test "renders card with additional attributes", %{assigns: assigns} do
      html = 
        rendered_to_string(~H"""
        <Card.card data-test-id="test-card">Card content</Card.card>
        """)
        
      assert html =~ ~r/data-test-id="test-card"/
    end
  end

  describe "card_header component" do
    test "renders header with content", %{assigns: assigns} do
      html = 
        rendered_to_string(~H"""
        <Card.card_header>Header content</Card.card_header>
        """)
        
      assert html =~ "Header content"
      assert html =~ "flex flex-col space-y-1.5 p-6"
    end

    test "renders header with custom class", %{assigns: assigns} do
      html = 
        rendered_to_string(~H"""
        <Card.card_header class="custom-header-class">Header content</Card.card_header>
        """)
        
      assert html =~ "custom-header-class"
    end
  end

  describe "card_title component" do
    test "renders title with content", %{assigns: assigns} do
      html = 
        rendered_to_string(~H"""
        <Card.card_title>Card Title</Card.card_title>
        """)
        
      assert html =~ "Card Title"
      assert html =~ "text-2xl font-semibold"
      assert html =~ ~r/<h3[^>]*>.*?Card Title.*?<\/h3>/s
    end

    test "renders title with custom class", %{assigns: assigns} do
      html = 
        rendered_to_string(~H"""
        <Card.card_title class="custom-title-class">Card Title</Card.card_title>
        """)
        
      assert html =~ "custom-title-class"
    end
  end

  describe "card_description component" do
    test "renders description with content", %{assigns: assigns} do
      html = 
        rendered_to_string(~H"""
        <Card.card_description>Card Description</Card.card_description>
        """)
        
      assert html =~ "Card Description"
      assert html =~ "text-sm text-muted-foreground"
      assert html =~ ~r/<p[^>]*>.*?Card Description.*?<\/p>/s
    end

    test "renders description with custom class", %{assigns: assigns} do
      html = 
        rendered_to_string(~H"""
        <Card.card_description class="custom-desc-class">Card Description</Card.card_description>
        """)
        
      assert html =~ "custom-desc-class"
    end
  end

  describe "card_content component" do
    test "renders content section", %{assigns: assigns} do
      html = 
        rendered_to_string(~H"""
        <Card.card_content>Main content</Card.card_content>
        """)
        
      assert html =~ "Main content"
      assert html =~ "p-6 pt-0"
    end

    test "renders content with custom class", %{assigns: assigns} do
      html = 
        rendered_to_string(~H"""
        <Card.card_content class="custom-content-class">Main content</Card.card_content>
        """)
        
      assert html =~ "custom-content-class"
    end
  end

  describe "card_footer component" do
    test "renders footer section", %{assigns: assigns} do
      html = 
        rendered_to_string(~H"""
        <Card.card_footer>Footer content</Card.card_footer>
        """)
        
      assert html =~ "Footer content"
      assert html =~ "flex items-center p-6 pt-0"
    end

    test "renders footer with custom class", %{assigns: assigns} do
      html = 
        rendered_to_string(~H"""
        <Card.card_footer class="custom-footer-class">Footer content</Card.card_footer>
        """)
        
      assert html =~ "custom-footer-class"
    end
  end

  describe "complete card component" do
    test "renders full card with all subcomponents", %{assigns: assigns} do
      html = 
        rendered_to_string(~H"""
        <Card.card>
          <Card.card_header>
            <Card.card_title>Example Card</Card.card_title>
            <Card.card_description>This is an example card description.</Card.card_description>
          </Card.card_header>
          <Card.card_content>
            This is the main content of the card.
          </Card.card_content>
          <Card.card_footer>
            <button>Action Button</button>
          </Card.card_footer>
        </Card.card>
        """)
        
      assert html =~ "Example Card"
      assert html =~ "This is an example card description."
      assert html =~ "This is the main content of the card."
      assert html =~ "Action Button"
      
      # Check proper nesting
      assert html =~ ~r/<div[^>]*>.*?<div[^>]*>.*?<h3[^>]*>.*?Example Card.*?<\/h3>/s
    end
  end
end