defmodule XIAMWeb.Components.UI.LabelTest do
  use ExUnit.Case, async: true
  
  import Phoenix.Component
  import Phoenix.LiveViewTest
  
  alias XIAMWeb.Components.UI.Label
  
  describe "label component" do
    test "renders a basic label" do
      assigns = %{}
      html = rendered_to_string(~H"""
      <Label.label for="test-input">Label Text</Label.label>
      """)
      
      assert html =~ ~s(for="test-input")
      assert html =~ ~s(Label Text)
      assert html =~ ~s(class="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70)
    end
    
    test "renders a label with custom class" do
      assigns = %{}
      html = rendered_to_string(~H"""
      <Label.label for="test-input" class="custom-class">Custom Label</Label.label>
      """)
      
      assert html =~ ~s(class="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70 custom-class")
      assert html =~ ~s(Custom Label)
    end
    
    test "renders a label with additional attributes" do
      assigns = %{}
      html = rendered_to_string(~H"""
      <Label.label for="test-input" data-test="label-test" aria-label="Test Label">Required Field</Label.label>
      """)
      
      assert html =~ ~s(for="test-input")
      assert html =~ ~s(data-test="label-test")
      assert html =~ ~s(aria-label="Test Label")
      assert html =~ ~s(Required Field)
    end
    
    test "renders without a for attribute" do
      assigns = %{}
      html = rendered_to_string(~H"""
      <Label.label>Generic Label</Label.label>
      """)
      
      refute html =~ ~s(for=)
      assert html =~ ~s(Generic Label)
    end
  end
end