defmodule XIAMWeb.Components.UI.InputTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias XIAMWeb.Components.UI.Input

  test "renders text input with default attributes" do
    html = render_component(&Input.input/1, %{})

    assert html =~ ~r/type="text"/
    assert html =~ "flex h-10 w-full rounded-md border border-input"
    refute html =~ ~r/disabled="true"/
  end

  test "renders input with different types" do
    html_email = render_component(&Input.input/1, %{type: "email"})
    html_password = render_component(&Input.input/1, %{type: "password"})
    html_number = render_component(&Input.input/1, %{type: "number"})

    assert html_email =~ ~r/type="email"/
    assert html_password =~ ~r/type="password"/
    assert html_number =~ ~r/type="number"/
  end

  test "renders input with ID and name" do
    html = render_component(&Input.input/1, %{id: "test-id", name: "test-name"})

    assert html =~ ~r/id="test-id"/
    assert html =~ ~r/name="test-name"/
  end

  test "renders input with value and placeholder" do
    html = render_component(&Input.input/1, %{value: "test-value", placeholder: "test-placeholder"})

    assert html =~ ~r/value="test-value"/
    assert html =~ ~r/placeholder="test-placeholder"/
  end

  test "renders input with required and disabled states" do
    html = render_component(&Input.input/1, %{required: true, disabled: true})

    assert html =~ ~r/required/
    assert html =~ ~r/disabled/
  end

  test "renders input with custom class" do
    html = render_component(&Input.input/1, %{class: "custom-class"})

    assert html =~ "custom-class"
    assert html =~ "flex h-10 w-full rounded-md border border-input"
  end

  test "passes additional HTML attributes" do
    html = render_component(&Input.input/1, %{autocomplete: "off", minlength: 5, maxlength: 10})

    assert html =~ ~r/autocomplete="off"/
    assert html =~ ~r/minlength="5"/
    assert html =~ ~r/maxlength="10"/
  end
end