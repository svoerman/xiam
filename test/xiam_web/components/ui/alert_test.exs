defmodule XIAMWeb.Components.UI.AlertTest do
  use ExUnit.Case
  import Phoenix.LiveViewTest
  import Phoenix.Component
  alias XIAMWeb.Components.UI.Alert

  setup do
    %{assigns: %{}}
  end

  describe "alert component" do
    test "renders alert with default variant", %{assigns: assigns} do
      html = 
        rendered_to_string(~H"""
        <Alert.alert>Alert content</Alert.alert>
        """)
        
      assert html =~ ~r/role="alert"/
      assert html =~ "Alert content"
      assert html =~ "bg-background text-foreground"
    end

    test "renders alert with destructive variant", %{assigns: assigns} do
      html = 
        rendered_to_string(~H"""
        <Alert.alert variant="destructive">Alert content</Alert.alert>
        """)
        
      assert html =~ ~r/role="alert"/
      assert html =~ "Alert content"
      assert html =~ "border-destructive"
    end

    test "renders alert with custom class", %{assigns: assigns} do
      html = 
        rendered_to_string(~H"""
        <Alert.alert class="custom-class">Alert content</Alert.alert>
        """)
        
      assert html =~ "custom-class"
    end

    test "renders alert with additional attributes", %{assigns: assigns} do
      html = 
        rendered_to_string(~H"""
        <Alert.alert data-test-id="test-alert">Alert content</Alert.alert>
        """)
        
      assert html =~ ~r/data-test-id="test-alert"/
    end
  end

  describe "alert_title component" do
    test "renders title with default class", %{assigns: assigns} do
      html = 
        rendered_to_string(~H"""
        <Alert.alert_title>Alert Title</Alert.alert_title>
        """)
        
      assert html =~ "Alert Title"
      assert html =~ "font-medium"
    end

    test "renders title with custom class", %{assigns: assigns} do
      html = 
        rendered_to_string(~H"""
        <Alert.alert_title class="custom-title-class">Alert Title</Alert.alert_title>
        """)
        
      assert html =~ "custom-title-class"
    end
  end

  describe "alert_description component" do
    test "renders description with default class", %{assigns: assigns} do
      html = 
        rendered_to_string(~H"""
        <Alert.alert_description>Alert Description</Alert.alert_description>
        """)
        
      assert html =~ "Alert Description"
      assert html =~ "text-sm"
    end

    test "renders description with custom class", %{assigns: assigns} do
      html = 
        rendered_to_string(~H"""
        <Alert.alert_description class="custom-desc-class">Alert Description</Alert.alert_description>
        """)
        
      assert html =~ "custom-desc-class"
    end
  end

  describe "complete alert component" do
    test "renders full alert with title and description", %{assigns: assigns} do
      html = 
        rendered_to_string(~H"""
        <Alert.alert>
          <Alert.alert_title>Warning</Alert.alert_title>
          <Alert.alert_description>This is a warning message.</Alert.alert_description>
        </Alert.alert>
        """)
        
      assert html =~ "Warning"
      assert html =~ "This is a warning message."
      assert html =~ ~r/<h5[^>]*>.*?Warning.*?<\/h5>/s
      assert html =~ ~r/<div[^>]*>.*?This is a warning message.*?<\/div>/s
    end
  end
end