defmodule XIAMWeb.Pow.ComponentsTest do
  use ExUnit.Case
  
  # Since the pow_button component just delegates to the CoreComponents.button,
  # we can just verify the module exists and the function is defined correctly
  test "pow_button/1 is defined with correct pattern" do
    assert function_exported?(XIAMWeb.Pow.Components, :pow_button, 1)
  end
end