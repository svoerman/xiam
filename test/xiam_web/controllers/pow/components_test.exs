defmodule XIAMWeb.Pow.ComponentsTest do
  use XIAMWeb.ConnCase

  import Phoenix.LiveViewTest
  import Phoenix.Component

  # Create a test module that uses the components
  defmodule TestComponent do
    use Phoenix.Component
    import XIAMWeb.Pow.Components

    def render(assigns) do
      ~H"""
      <div class="test-container">
        <.pow_button type="button" class="custom-class" rest={%{}}>
          Submit
        </.pow_button>
      </div>
      """
    end
  end

  # Component to test pow_button with specific attributes
  defmodule ButtonComparisonComponent do
    use Phoenix.Component
    import XIAMWeb.Pow.Components

    def render_pow_button(assigns) do
      ~H"""
      <.pow_button type={@type} class={@class} rest={@rest}>
        <%= @text %>
      </.pow_button>
      """
    end
  end

  # Component to test CoreComponents.button
  defmodule CoreButtonComponent do
    use Phoenix.Component
    import XIAMWeb.CoreComponents

    def render_core_button(assigns) do
      ~H"""
      <.button type={@type} class={@class} disabled={@disabled}>
        <%= @text %>
      </.button>
      """
    end
  end

  test "pow_button renders correctly", %{conn: _conn} do
    html = render_component(&TestComponent.render/1, %{})

    # Convert to string for easier matching
    html_str = html |> to_string()

    # Verify button structure
    assert html_str =~ ~s|<button type="button"|
    assert html_str =~ ~s|class="|
    assert html_str =~ ~s|custom-class|
    assert html_str =~ ~s|Submit|
  end

  test "pow_button delegates to CoreComponents.button", %{conn: _conn} do
    # Test that pow_button is defined with the correct arity
    assert function_exported?(XIAMWeb.Pow.Components, :pow_button, 1)

    # We can also assert that it renders HTML similar to button
    html1 = render_component(&ButtonComparisonComponent.render_pow_button/1, %{
      type: "submit",
      class: "test",
      rest: %{disabled: true},
      text: "Test"
    })

    html2 = render_component(&CoreButtonComponent.render_core_button/1, %{
      type: "submit",
      class: "test",
      disabled: true,
      text: "Test"
    })

    # Both should include the same attributes (though order might differ)
    html1_str = html1 |> to_string()
    html2_str = html2 |> to_string()

    # Test basic attributes in both buttons
    assert html1_str =~ ~s|<button|
    assert html1_str =~ ~s|type="submit"|
    assert html1_str =~ ~s|class="|
    assert html1_str =~ ~s|test|
    assert html1_str =~ ~s|disabled|
    assert html1_str =~ ~s|Test|

    assert html2_str =~ ~s|<button|
    assert html2_str =~ ~s|type="submit"|
    assert html2_str =~ ~s|class="|
    assert html2_str =~ ~s|test|
    assert html2_str =~ ~s|disabled|
    assert html2_str =~ ~s|Test|
  end
end
