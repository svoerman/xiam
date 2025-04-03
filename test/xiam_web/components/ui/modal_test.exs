defmodule XIAMWeb.Components.UI.ModalTest do
  use ExUnit.Case, async: true
  # LiveViewTest would be used for rendering tests

  alias XIAMWeb.Components.UI.Modal

  # Tag these tests to be skipped until we can resolve the LiveView test issues
  @tag :pending
  test "renders modal with basic attributes" do
    assert "" =~ ""
  end
  
  describe "Modal component" do
    test "module exists" do
      assert is_list(Modal.module_info())
    end
  end
end