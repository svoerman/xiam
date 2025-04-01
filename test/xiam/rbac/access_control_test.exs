defmodule Xiam.Rbac.AccessControlTest do
  use XIAM.DataCase

  alias Xiam.Rbac.AccessControl
  alias Xiam.Rbac.{EntityAccess, Product, Capability, Role}
  alias XIAM.Users.User
  alias XIAM.Repo

  describe "entity_access" do
    setup do
      # Create a test user
      {:ok, user} = %User{}
        |> User.pow_changeset(%{
          email: "access_test@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })
        |> Repo.insert()

      # Create a role
      {:ok, role} = %Role{
        name: "Test Role",
        description: "Role for testing"
      }
      |> Repo.insert()

      # Create a product
      {:ok, product} = %Product{
        product_name: "Test Product",
        description: "Product for testing"
      }
      |> Repo.insert()

      # Create a capability
      {:ok, capability} = %Capability{
        name: "test_capability",
        description: "Capability for testing",
        product_id: product.id
      }
      |> Repo.insert()

      {:ok, user: user, role: role, product: product, capability: capability}
    end

    test "set_user_access/1 creates a new entity access", %{user: user, role: role} do
      attrs = %{
        user_id: user.id,
        entity_type: "test_entity",
        entity_id: 123,
        role_id: role.id
      }

      assert {:ok, entity_access} = AccessControl.set_user_access(attrs)
      assert entity_access.user_id == user.id
      assert entity_access.entity_type == "test_entity"
      assert entity_access.entity_id == 123
      assert entity_access.role_id == role.id
    end

    test "get_user_access/1 retrieves access for a user", %{user: user, role: role} do
      # Insert multiple access entries
      Repo.insert!(%EntityAccess{
        user_id: user.id,
        entity_type: "test_entity",
        entity_id: 123,
        role_id: role.id
      })

      Repo.insert!(%EntityAccess{
        user_id: user.id,
        entity_type: "test_entity",
        entity_id: 456,
        role_id: role.id
      })

      access_list = AccessControl.get_user_access(user.id)
      assert length(access_list) == 2
      assert Enum.all?(access_list, fn access -> access.user_id == user.id end)
    end

    test "list_entity_access/0 returns all entity access entries", %{user: user, role: role} do
      # Insert access entry
      Repo.insert!(%EntityAccess{
        user_id: user.id,
        entity_type: "test_entity",
        entity_id: 123,
        role_id: role.id
      })

      access_list = AccessControl.list_entity_access()
      assert length(access_list) >= 1
    end

    test "has_access?/3 correctly checks user access", %{user: user, role: role} do
      # Insert access entry
      Repo.insert!(%EntityAccess{
        user_id: user.id,
        entity_type: "test_entity",
        entity_id: 123,
        role_id: role.id
      })

      assert AccessControl.has_access?(user.id, "test_entity", 123) == true
      assert AccessControl.has_access?(user.id, "test_entity", 456) == false
      assert AccessControl.has_access?(user.id, "different_entity", 123) == false
    end

    test "delete_entity_access/1 removes access", %{user: user, role: role} do
      # Insert access entry
      access = Repo.insert!(%EntityAccess{
        user_id: user.id,
        entity_type: "test_entity",
        entity_id: 123,
        role_id: role.id
      })

      assert {:ok, _} = AccessControl.delete_entity_access(access)
      assert AccessControl.has_access?(user.id, "test_entity", 123) == false
    end
  end

  describe "products" do
    test "create_product/1 creates a new product" do
      attrs = %{
        product_name: "New Product",
        description: "A new test product"
      }

      assert {:ok, product} = AccessControl.create_product(attrs)
      assert product.product_name == "New Product"
      assert product.description == "A new test product"
    end

    test "list_products/0 returns all products" do
      # Create a product
      Repo.insert!(%Product{
        product_name: "List Test Product",
        description: "Product for testing list"
      })

      products = AccessControl.list_products()
      assert length(products) >= 1
      assert Enum.any?(products, fn p -> p.product_name == "List Test Product" end)
    end

    test "get_product/1 returns a specific product" do
      # Create a product
      product = Repo.insert!(%Product{
        product_name: "Get Test Product",
        description: "Product for testing get"
      })

      retrieved_product = AccessControl.get_product(product.id)
      assert retrieved_product.id == product.id
      assert retrieved_product.product_name == "Get Test Product"
    end

    test "update_product/2 updates a product" do
      # Create a product
      product = Repo.insert!(%Product{
        product_name: "Update Test Product",
        description: "Original description"
      })

      attrs = %{description: "Updated description"}
      assert {:ok, updated_product} = AccessControl.update_product(product, attrs)
      assert updated_product.id == product.id
      assert updated_product.description == "Updated description"
    end

    test "delete_product/1 deletes a product" do
      # Create a product
      product = Repo.insert!(%Product{
        product_name: "Delete Test Product",
        description: "Product for testing delete"
      })

      assert {:ok, _} = AccessControl.delete_product(product)
      assert AccessControl.get_product(product.id) == nil
    end
  end

  describe "capabilities" do
    setup do
      # Create a product for capabilities to reference
      {:ok, product} = %Product{
        product_name: "Capability Test Product",
        description: "Product for capability tests"
      }
      |> Repo.insert()

      {:ok, product: product}
    end

    test "create_capability/1 creates a new capability", %{product: product} do
      attrs = %{
        name: "new_capability",
        description: "A new test capability",
        product_id: product.id
      }

      assert {:ok, capability} = AccessControl.create_capability(attrs)
      assert capability.name == "new_capability"
      assert capability.description == "A new test capability"
      assert capability.product_id == product.id
    end

    test "list_capabilities/0 returns all capabilities", %{product: product} do
      # Create a capability
      Repo.insert!(%Capability{
        name: "list_test_capability",
        description: "Capability for testing list",
        product_id: product.id
      })

      capabilities = AccessControl.list_capabilities()
      assert length(capabilities) >= 1
      assert Enum.any?(capabilities, fn c -> c.name == "list_test_capability" end)
    end

    test "get_capability/1 returns a specific capability", %{product: product} do
      # Create a capability
      capability = Repo.insert!(%Capability{
        name: "get_test_capability",
        description: "Capability for testing get",
        product_id: product.id
      })

      retrieved_capability = AccessControl.get_capability(capability.id)
      assert retrieved_capability.id == capability.id
      assert retrieved_capability.name == "get_test_capability"
    end

    test "update_capability/2 updates a capability", %{product: product} do
      # Create a capability
      capability = Repo.insert!(%Capability{
        name: "update_test_capability",
        description: "Original description",
        product_id: product.id
      })

      attrs = %{description: "Updated description"}
      assert {:ok, updated_capability} = AccessControl.update_capability(capability, attrs)
      assert updated_capability.id == capability.id
      assert updated_capability.description == "Updated description"
    end

    test "delete_capability/1 deletes a capability", %{product: product} do
      # Create a capability
      capability = Repo.insert!(%Capability{
        name: "delete_test_capability",
        description: "Capability for testing delete",
        product_id: product.id
      })

      assert {:ok, _} = AccessControl.delete_capability(capability)
      assert AccessControl.get_capability(capability.id) == nil
    end

    test "get_product_capabilities/1 returns capabilities for a product", %{product: product} do
      # Create a capability
      Repo.insert!(%Capability{
        name: "product_test_capability",
        description: "Capability for testing product capabilities",
        product_id: product.id
      })

      capabilities = AccessControl.get_product_capabilities(product.id)
      assert length(capabilities) >= 1
      assert Enum.any?(capabilities, fn c -> c.name == "product_test_capability" end)
    end
  end
end