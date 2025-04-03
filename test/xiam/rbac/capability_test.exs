defmodule Xiam.Rbac.CapabilityTest do
  use XIAM.DataCase

  alias Xiam.Rbac.Capability
  # Import required modules only
  alias Xiam.Rbac.AccessControl

  # Set up test data
  setup do
    # Generate a unique timestamp for this test run
    timestamp = System.system_time(:second)
    
    # Clean up any existing test data that might interfere
    product_name = "Test_Cap_Product_#{timestamp}"
    capability_pattern = "%test_capability_#{timestamp}%"
    
    Repo.delete_all(from p in Xiam.Rbac.Product, 
                    where: p.product_name == ^product_name)
    Repo.delete_all(from c in Xiam.Rbac.Capability, 
                    where: like(c.name, ^capability_pattern))
    
    # Create a product for the capabilities with a unique name
    {:ok, product} = AccessControl.create_product(%{
      product_name: "Test_Cap_Product_#{timestamp}",
      description: "Product for testing capabilities"
    })

    # Create test data with unique capability name
    valid_attrs = %{
      name: "test_capability_#{timestamp}",
      description: "Test capability",
      product_id: product.id
    }

    update_attrs = %{
      name: "updated_capability_#{timestamp}",
      description: "Updated description"
    }

    invalid_attrs = %{
      name: nil,
      description: "Description without name",
      product_id: product.id
    }

    %{
      product: product,
      valid_attrs: valid_attrs,
      update_attrs: update_attrs,
      invalid_attrs: invalid_attrs
    }
  end

  describe "capability schema" do
    test "changeset with valid attributes", %{valid_attrs: valid_attrs} do
      changeset = Capability.changeset(%Capability{}, valid_attrs)
      assert changeset.valid?
    end

    test "changeset with invalid attributes", %{invalid_attrs: invalid_attrs} do
      changeset = Capability.changeset(%Capability{}, invalid_attrs)
      refute changeset.valid?
    end

    test "changeset enforces unique capability name within product", %{valid_attrs: valid_attrs} do
      # First create a capability
      {:ok, _capability} = AccessControl.create_capability(valid_attrs)
      
      # Try to create another capability with the same name for the same product
      {:error, changeset} = AccessControl.create_capability(valid_attrs)
      
      assert %{product_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "changeset allows same capability name for different products", %{valid_attrs: valid_attrs} do
      # First create a capability
      {:ok, _capability} = AccessControl.create_capability(valid_attrs)
      
      # Create another product with unique name
      {:ok, another_product} = AccessControl.create_product(%{
        product_name: "Another_Product_#{System.system_time(:second)}",
        description: "Another product for testing"
      })
      
      # Create capability with same name but different product
      same_name_attrs = %{
        name: valid_attrs.name,
        description: valid_attrs.description,
        product_id: another_product.id
      }
      
      {:ok, capability2} = AccessControl.create_capability(same_name_attrs)
      assert capability2.name == valid_attrs.name
      assert capability2.product_id == another_product.id
    end
  end

  describe "capability CRUD operations" do
    test "create_capability/1 with valid data creates a capability", %{valid_attrs: valid_attrs} do
      {:ok, capability} = Capability.create_capability(valid_attrs)
      assert capability.name == valid_attrs.name
      assert capability.description == valid_attrs.description
      assert capability.product_id == valid_attrs.product_id
    end

    test "create_capability/1 with invalid data returns error changeset", %{invalid_attrs: invalid_attrs} do
      {:error, changeset} = Capability.create_capability(invalid_attrs)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "get_capability!/1 returns the capability with given id", %{valid_attrs: valid_attrs} do
      {:ok, capability} = Capability.create_capability(valid_attrs)
      assert Capability.get_capability!(capability.id) == capability
    end

    test "get_capability_by_name/1 returns the capability with given name", %{valid_attrs: valid_attrs} do
      {:ok, capability} = Capability.create_capability(valid_attrs)
      found = Capability.get_capability_by_name(valid_attrs.name)
      assert found.id == capability.id
    end

    test "list_capabilities/0 returns all capabilities", %{valid_attrs: valid_attrs} do
      {:ok, capability} = Capability.create_capability(valid_attrs)
      
      # Generate unique name for the second capability
      second_cap_name = "another_capability_#{System.system_time(:second)}"
      
      # Create a second capability with unique name
      {:ok, capability2} = Capability.create_capability(%{
        name: second_cap_name,
        description: "Another test capability",
        product_id: valid_attrs.product_id
      })
      
      capabilities = Capability.list_capabilities()
      # There may be capabilities from previous tests, so just check ours exist
      assert length(capabilities) >= 2
      assert Enum.any?(capabilities, fn c -> c.id == capability.id end)
      assert Enum.any?(capabilities, fn c -> c.id == capability2.id end)
    end

    test "update_capability/2 with valid data updates the capability", %{valid_attrs: valid_attrs, update_attrs: update_attrs} do
      {:ok, capability} = Capability.create_capability(valid_attrs)
      {:ok, updated} = Capability.update_capability(capability, update_attrs)
      
      assert updated.name == update_attrs.name
      assert updated.description == update_attrs.description
    end

    test "update_capability/2 with invalid data returns error changeset", %{valid_attrs: valid_attrs, invalid_attrs: invalid_attrs} do
      {:ok, capability} = Capability.create_capability(valid_attrs)
      {:error, changeset} = Capability.update_capability(capability, invalid_attrs)
      
      assert %{name: ["can't be blank"]} = errors_on(changeset)
      # The capability should remain unchanged
      assert Capability.get_capability!(capability.id) == capability
    end

    test "delete_capability/1 deletes the capability", %{valid_attrs: valid_attrs} do
      {:ok, capability} = Capability.create_capability(valid_attrs)
      {:ok, _} = Capability.delete_capability(capability)
      
      assert_raise Ecto.NoResultsError, fn -> Capability.get_capability!(capability.id) end
    end
  end

  describe "capabilities via AccessControl context" do
    test "AccessControl.create_capability/1 creates a capability", %{valid_attrs: valid_attrs} do
      {:ok, capability} = AccessControl.create_capability(valid_attrs)
      assert capability.name == valid_attrs.name
    end

    test "AccessControl.get_capability/1 returns a capability by ID", %{valid_attrs: valid_attrs} do
      {:ok, capability} = AccessControl.create_capability(valid_attrs)
      assert AccessControl.get_capability(capability.id) == capability
    end

    test "AccessControl.list_capabilities/0 returns all capabilities with preloaded products", %{valid_attrs: valid_attrs} do
      {:ok, capability} = AccessControl.create_capability(valid_attrs)
      
      capabilities = AccessControl.list_capabilities()
      
      # There may be capabilities from previous tests, so we just check ours exists
      assert length(capabilities) >= 1
      assert Enum.any?(capabilities, fn c -> c.id == capability.id end)
      
      # Find our capability in the result
      loaded_capability = Enum.find(capabilities, &(&1.id == capability.id))
      assert loaded_capability.product != nil
      assert loaded_capability.product.id == valid_attrs.product_id
    end

    test "AccessControl.update_capability/2 updates a capability", %{valid_attrs: valid_attrs, update_attrs: update_attrs} do
      {:ok, capability} = AccessControl.create_capability(valid_attrs)
      {:ok, updated} = AccessControl.update_capability(capability, update_attrs)
      
      assert updated.name == update_attrs.name
    end

    test "AccessControl.delete_capability/1 deletes a capability", %{valid_attrs: valid_attrs} do
      {:ok, capability} = AccessControl.create_capability(valid_attrs)
      {:ok, _} = AccessControl.delete_capability(capability)
      
      assert AccessControl.get_capability(capability.id) == nil
    end
  end
end