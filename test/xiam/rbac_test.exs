defmodule Xiam.RbacTest do
  use XIAM.DataCase
  
  alias Xiam.Rbac
  alias Xiam.Rbac.Role
  alias Xiam.Rbac.Capability

  describe "roles" do
    @valid_attrs %{name: "admin", description: "Administrator role"}
    # Unused but kept for future use
    # @update_attrs %{name: "super-admin", description: "Super administrator role"}
    @invalid_attrs %{name: nil, description: nil}

    test "list_roles/0 returns all roles" do
      # Insert a role for testing
      {:ok, role} = Repo.insert(%Role{name: "test-role", description: "A test role"})
      
      # Get the list of roles
      roles = Rbac.list_roles()
      
      # Verify that our test role is in the list
      assert Enum.any?(roles, fn r -> r.id == role.id end)
    end

    test "get_role/1 returns the role with given id" do
      # Insert a role for testing
      {:ok, role} = Repo.insert(%Role{name: "test-role", description: "A test role"})
      
      # Get the role by ID
      retrieved_role = Rbac.get_role(role.id)
      
      # Verify it's the same role
      assert retrieved_role.id == role.id
      assert retrieved_role.name == role.name
      assert retrieved_role.description == role.description
    end

    test "create_role/1 with valid data creates a role" do
      # Generate a unique name to avoid conflicts
      timestamp = System.system_time(:millisecond)
      attrs = Map.put(@valid_attrs, :name, "#{@valid_attrs.name}-#{timestamp}")
      
      # Create the role
      assert {:ok, %Role{} = role} = Rbac.create_role(attrs)
      assert role.name == attrs.name
      assert role.description == "Administrator role"
    end

    test "create_role/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Rbac.create_role(@invalid_attrs)
    end

    test "update_role/2 with valid data updates the role" do
      # Create a role to update
      timestamp = System.system_time(:millisecond)
      {:ok, role} = Repo.insert(%Role{name: "update-test-#{timestamp}", description: "Role to update"})
      
      # Update the role
      update_attrs = %{description: "Updated description"}
      assert {:ok, %Role{} = updated_role} = Rbac.update_role(role, update_attrs)
      assert updated_role.description == "Updated description"
    end

    test "update_role/2 with invalid data returns error changeset" do
      # Create a role to update
      timestamp = System.system_time(:millisecond)
      {:ok, role} = Repo.insert(%Role{name: "update-invalid-#{timestamp}", description: "Role for invalid update"})
      
      # Attempt invalid update
      assert {:error, %Ecto.Changeset{}} = Rbac.update_role(role, @invalid_attrs)
      
      # Verify role wasn't changed
      unchanged_role = Rbac.get_role(role.id)
      assert unchanged_role.name == role.name
      assert unchanged_role.description == role.description
    end

    test "delete_role/1 deletes the role" do
      # Create a role to delete
      timestamp = System.system_time(:millisecond)
      {:ok, role} = Repo.insert(%Role{name: "delete-test-#{timestamp}", description: "Role to delete"})
      
      # Delete the role
      assert {:ok, %Role{}} = Rbac.delete_role(role)
      
      # Verify it's gone
      assert nil == Rbac.get_role(role.id)
    end

    test "change_role/2 returns a role changeset" do
      # Create a role to change
      timestamp = System.system_time(:millisecond)
      {:ok, role} = Repo.insert(%Role{name: "changeset-test-#{timestamp}", description: "Role for changeset"})
      
      assert %Ecto.Changeset{} = Rbac.change_role(role)
    end
  end

  describe "capabilities" do
    @valid_attrs %{name: "read_users", description: "Can read users"}
    # Define attributes for updating (used in update tests)
  # Unused but kept for future use
  # @update_attrs %{name: "write_users", description: "Can write users"}
    @invalid_attrs %{name: nil, description: nil}

    def capability_fixture(attrs \\ %{}) do
      # Create a product for the capability
      timestamp = System.system_time(:millisecond)
      {:ok, product} = Repo.insert(%Xiam.Rbac.Product{
        product_name: "test-product-#{timestamp}",
        description: "Test product"
      })
      
      # Merge the attributes with defaults
      attrs = 
        attrs
        |> Enum.into(@valid_attrs)
        |> Map.put(:name, "#{@valid_attrs.name}-#{timestamp}")
        |> Map.put(:product_id, product.id)
      
      # Create the capability
      {:ok, capability} = Repo.insert(%Capability{
        name: attrs.name,
        description: attrs.description,
        product_id: attrs.product_id
      })
      
      capability
    end

    test "list_capabilities/0 returns all capabilities" do
      capability = capability_fixture()
      capabilities = Rbac.list_capabilities()
      assert Enum.any?(capabilities, fn c -> c.id == capability.id end)
    end

    test "get_capability/1 returns the capability with given id" do
      capability = capability_fixture()
      retrieved_capability = Rbac.get_capability(capability.id)
      assert retrieved_capability.id == capability.id
      assert retrieved_capability.name == capability.name
    end

    test "create_capability/1 with valid data creates a capability" do
      # Create a product for the capability
      timestamp = System.system_time(:millisecond)
      {:ok, product} = Repo.insert(%Xiam.Rbac.Product{
        product_name: "create-cap-product-#{timestamp}",
        description: "Test product for capability creation"
      })
      
      # Build the capability attributes
      attrs = %{
        name: "create-test-#{timestamp}",
        description: "Test capability",
        product_id: product.id
      }
      
      # Create the capability
      assert {:ok, %Capability{} = capability} = Rbac.create_capability(attrs)
      assert capability.name == attrs.name
      assert capability.description == attrs.description
      assert capability.product_id == product.id
    end

    test "create_capability/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Rbac.create_capability(@invalid_attrs)
    end

    test "update_capability/2 with valid data updates the capability" do
      capability = capability_fixture()
      
      # Update the capability
      update_attrs = %{description: "Updated capability description"}
      assert {:ok, %Capability{} = updated_capability} = Rbac.update_capability(capability, update_attrs)
      assert updated_capability.description == "Updated capability description"
    end

    test "update_capability/2 with invalid data returns error changeset" do
      capability = capability_fixture()
      assert {:error, %Ecto.Changeset{}} = Rbac.update_capability(capability, @invalid_attrs)
      
      # Verify capability wasn't changed
      unchanged_capability = Rbac.get_capability(capability.id)
      assert unchanged_capability.name == capability.name
      assert unchanged_capability.description == capability.description
    end

    test "delete_capability/1 deletes the capability" do
      capability = capability_fixture()
      assert {:ok, %Capability{}} = Rbac.delete_capability(capability)
      assert nil == Rbac.get_capability(capability.id)
    end

    test "change_capability/2 returns a capability changeset" do
      capability = capability_fixture()
      assert %Ecto.Changeset{} = Rbac.change_capability(capability)
    end
  end
end