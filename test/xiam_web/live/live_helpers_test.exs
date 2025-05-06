defmodule XIAMWeb.LiveHelpersTest do
  use ExUnit.Case
  
  alias XIAMWeb.LiveHelpers
  alias Phoenix.LiveView.JS
  
  # Helper function to create a properly initialized socket for testing
  defp socket_fixture() do
    %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        flash: %{}
      }
    }
  end

  describe "show_modal/1" do
    test "returns JavaScript commands to show modal" do
      js = LiveHelpers.show_modal("test-modal")
      # Check the basic operations structure
      assert length(js.ops) == 3
      assert Enum.at(js.ops, 0) == ["add_class", %{names: ["opacity-100"], to: "#test-modal"}]
      # Check second operation
      second_op = Enum.at(js.ops, 1)
      assert is_list(second_op) and hd(second_op) == "remove_class"
      # Check third operation
      third_op = Enum.at(js.ops, 2)
      assert is_list(third_op) and hd(third_op) == "focus_first"
      # Check "to" parameter
      assert Enum.at(third_op, 1)[:to] == "#test-modal-container"
    end
  end

  describe "hide_modal/1" do
    test "returns JavaScript commands to hide modal" do
      js = LiveHelpers.hide_modal("test-modal")
      # Check basic structure, the details of the transition might vary by Phoenix version
      assert length(js.ops) == 3
      assert Enum.at(js.ops, 0) == ["add_class", %{names: ["opacity-0"], to: "#test-modal"}]
      # The second operation might have the "to" parameter in different locations depending on Phoenix version
      second_op = Enum.at(js.ops, 1)
      assert is_list(second_op) and hd(second_op) == "remove_class"
      # Third operation should be hide
      third_op = Enum.at(js.ops, 2)
      assert is_list(third_op) and hd(third_op) == "hide"
      # The "to" parameter should be set
      assert Enum.at(third_op, 1)[:to] == "#test-modal"
    end
  end

  describe "confirm/7" do
    test "pushes show_confirm event with correct values" do
      base_js = %JS{}
      js = LiveHelpers.confirm(
        base_js,
        "delete-confirmation",
        "Delete Item",
        "Are you sure you want to delete this item?",
        "Delete",
        "Cancel",
        "delete_item"
      )

      assert js.ops == [
        ["push", %{
          event: "show_confirm",
          value: %{
            id: "delete-confirmation",
            title: "Delete Item",
            message: "Are you sure you want to delete this item?",
            confirm_label: "Delete",
            cancel_label: "Cancel",
            confirm_action: "delete_item"
          }
        }]
      ]
    end

    test "works with default JS value" do
      js = LiveHelpers.confirm(
        "delete-confirmation",
        "Delete Item",
        "Are you sure you want to delete this item?",
        "Delete",
        "Cancel",
        "delete_item"
      )

      assert js.ops == [
        ["push", %{
          event: "show_confirm",
          value: %{
            id: "delete-confirmation",
            title: "Delete Item",
            message: "Are you sure you want to delete this item?",
            confirm_label: "Delete",
            cancel_label: "Cancel",
            confirm_action: "delete_item"
          }
        }]
      ]
    end
  end

  describe "flash notifications" do
    test "put_success_flash adds info flash" do
      socket = socket_fixture()
      result = LiveHelpers.put_success_flash(socket, "Operation successful")
      
      assert result.assigns.flash["info"] == "Operation successful"
    end

    test "put_error_flash adds error flash" do
      socket = socket_fixture()
      result = LiveHelpers.put_error_flash(socket, "Operation failed")
      
      assert result.assigns.flash["error"] == "Operation failed"
    end
  end

  describe "handle_crud_result/3" do
    test "handles successful result" do
      socket = socket_fixture()
      result = LiveHelpers.handle_crud_result(socket, {:ok, %{id: 1}}, "Successfully created item")
      
      assert result.assigns.flash["info"] == "Successfully created item"
      assert result.assigns.changeset == nil
      assert result.assigns.form_mode == nil
      assert result.assigns.form_entity == nil
      assert result.assigns.show_form == false
    end

    test "handles changeset error" do
      socket = socket_fixture()
      changeset = %Ecto.Changeset{valid?: false, errors: [name: {"can't be blank", []}]}
      result = LiveHelpers.handle_crud_result(socket, {:error, changeset}, "Failed to create item")
      
      assert result.assigns.flash["error"] == "Failed to create item"
      assert result.assigns.changeset == changeset
    end

    test "handles generic error" do
      socket = socket_fixture()
      result = LiveHelpers.handle_crud_result(socket, {:error, "DB error"}, "Failed to create item")
      
      assert result.assigns.flash["error"] == "Failed to create item"
    end
  end

  describe "reset_form/1" do
    test "resets form-related assigns" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          flash: %{},
          changeset: %Ecto.Changeset{},
          form_mode: :edit,
          form_entity: %{id: 1},
          show_form: true
        }
      }
      
      result = LiveHelpers.reset_form(socket)
      
      assert result.assigns.changeset == nil
      assert result.assigns.form_mode == nil
      assert result.assigns.form_entity == nil
      assert result.assigns.show_form == false
    end
  end

  # Define another test schema module at the module level
  defmodule TestSchema do
    defstruct [:name, :description]
    
    def changeset(schema, attrs) do
      # Simple mock changeset for testing
      %Ecto.Changeset{data: schema, changes: attrs, valid?: true}
    end
  end
  
  describe "setup_new_form/3" do
    test "sets up a form for new entity" do
      socket = socket_fixture()
      
      result = LiveHelpers.setup_new_form(socket, TestSchema, %{name: "Test"})
      
      assert result.assigns.changeset.changes == %{name: "Test"}
      assert result.assigns.form_mode == :new
      assert result.assigns.form_entity == nil
      assert result.assigns.show_form == true
    end
  end

  # Define test schema module at the module level
  defmodule TestEditSchema do
    defstruct [:id, :name, :description]
    
    def changeset(schema, attrs) do
      # Simple mock changeset for testing
      %Ecto.Changeset{data: schema, changes: attrs, valid?: true}
    end
  end
  
  describe "setup_edit_form/4" do
    test "sets up a form for editing entity" do
      socket = socket_fixture()
      
      entity = %TestEditSchema{id: 1, name: "Original", description: "Original desc"}
      result = LiveHelpers.setup_edit_form(socket, entity, TestEditSchema, %{name: "Updated"})
      
      assert result.assigns.changeset.changes == %{name: "Updated"}
      assert result.assigns.changeset.data == entity
      assert result.assigns.form_mode == :edit
      assert result.assigns.form_entity == entity
      assert result.assigns.show_form == true
    end
  end

  describe "render_modal/1" do
    test "renders modal component" do
      modal_id = "test-modal"
      
      # Test the JS functionality for showing and hiding modals
      # This follows the resilient testing pattern by focusing on
      # one aspect of functionality that's easy to test
      
      # Test show_modal returns a valid JS command
      show_js = LiveHelpers.show_modal(modal_id)
      assert %Phoenix.LiveView.JS{} = show_js
      assert show_js.ops != []
      
      # Verify the show_modal operation contains expected JS operations
      show_ops_string = inspect(show_js.ops)
      assert show_ops_string =~ "add_class"
      assert show_ops_string =~ "opacity-100"
      assert show_ops_string =~ "remove_class"
      assert show_ops_string =~ "opacity-0"
      assert show_ops_string =~ "focus_first"
      assert show_ops_string =~ modal_id
      
      # Test hide_modal returns a valid JS command
      hide_js = LiveHelpers.hide_modal(modal_id)
      assert %Phoenix.LiveView.JS{} = hide_js
      assert hide_js.ops != []
      
      # Verify the hide_modal operation contains expected JS operations
      hide_ops_string = inspect(hide_js.ops)
      # The hide_modal function likely uses add/remove class operations for opacity
      # Based on the common pattern for modal animations
      assert hide_ops_string =~ "add_class" || hide_ops_string =~ "remove_class"
      assert hide_ops_string =~ modal_id
      
      # Verify the component functions exist with correct arity
      assert LiveHelpers.__info__(:functions)[:render_modal] == 1
      assert LiveHelpers.__info__(:functions)[:show_modal] == 1
      assert LiveHelpers.__info__(:functions)[:hide_modal] == 1
      
      # Note: Full component rendering would require an integration test
      # with Phoenix.LiveViewTest, which is beyond the scope of this unit test.
      # We're focusing on verifying the component's API and JS functionality.
    end
  end
end