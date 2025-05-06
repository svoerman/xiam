defmodule Xiam.Rbac.AccessControlTest do
  use XIAM.DataCase, async: false

  alias Xiam.Rbac.AccessControl
  alias Xiam.Rbac.Role
  alias XIAM.Users.User
  alias XIAM.Repo

  describe "entity_access" do
    setup do
      # More resilient pattern for checking out the database connection
      case Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo) do
        :ok -> :ok
        {:already, :owner} -> :ok
        _ -> 
          # If checkout fails, try to ensure the repository is started
          {:ok, _} = Application.ensure_all_started(:ecto_sql)
          {:ok, _} = XIAM.Repo.start_link([])
          :ok = Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo)
      end
      
      # Always set sandbox mode to shared for this process
      Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
      
      # Generate unique identifiers for this test run
      timestamp = System.system_time(:second)
      email = "access_test_#{timestamp}@example.com"
      role_name = "Test_Role_#{timestamp}"
      product_name = "Test_Product_#{timestamp}"
      capability_name = "test_capability_#{timestamp}"
      
      # Register a teardown function to clean up test data
      # We use checkout inside the function so the connection isn't lost between setup and teardown
      # This prevents ownership errors when the function exits
      on_exit(fn ->
        # Use our resilient pattern for database operations
        XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
          # Get our own connection for cleanup - don't rely on the test connection which might be gone
          case Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo) do
            :ok -> :ok
            {:already, :owner} -> :ok
          end
          
          # Set shared mode to ensure subprocesses can access the connection
          Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
          
          import Ecto.Query
          # First delete entity access records
          Repo.delete_all(from ea in Xiam.Rbac.EntityAccess, 
                          join: u in User, on: ea.user_id == u.id,
                          where: like(u.email, "%access_test%"))
        end)
      end)
      
      # Clear any test data that might interfere - in the correct order to respect foreign keys
      import Ecto.Query
      # First delete entity access records that depend on users and roles
      Repo.delete_all(from ea in Xiam.Rbac.EntityAccess, 
                      join: u in User, on: ea.user_id == u.id,
                      join: r in Role, on: ea.role_id == r.id,
                      where: like(u.email, "%access_test%") or like(r.name, "%Test_Role%"))
      
      # Then delete other records
      Repo.delete_all(from u in User, where: like(u.email, "%access_test%"))
      Repo.delete_all(from r in Role, where: like(r.name, "%Test_Role%"))
      Repo.delete_all(from p in Xiam.Rbac.Product, where: like(p.product_name, "%Test_Product%"))
      
      # Create a test user with unique email
      {:ok, user} = %User{}
        |> User.pow_changeset(%{
          email: email,
          password: "Password123!",
          password_confirmation: "Password123!"
        })
        |> Repo.insert()

      # Create a role with unique name
      {:ok, role} = %Role{
        name: role_name,
        description: "Role for testing"
      }
      |> Repo.insert()

      # Create a product using the AccessControl context with unique name
      {:ok, product} = AccessControl.create_product(%{
        product_name: product_name,
        description: "Product for testing"
      })

      # Create a capability using the AccessControl context with unique name
      {:ok, capability} = AccessControl.create_capability(%{
        name: capability_name,
        description: "Capability for testing",
        product_id: product.id
      })

      {:ok, user: user, role: role, product: product, capability: capability}
    end

    test "set_user_access/1 creates a new entity access", %{user: user, role: role} do
      # Use resilient test helper to handle potential DB connection issues
      XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        # Ensure we have ownership of the DB connection for this test
        case Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo) do
          :ok -> :ok
          {:already, :owner} -> :ok
        end
        
        # Set shared mode to ensure subprocesses can access the connection
        Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
        
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
      end)
    end

    test "get_user_access/1 retrieves access for a user", %{user: user, role: role} do
      # Use resilient test helper to handle potential DB connection issues
      XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        # Ensure we have ownership of the DB connection for this test
        case Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo) do
          :ok -> :ok
          {:already, :owner} -> :ok
        end
        
        # Set shared mode to ensure subprocesses can access the connection
        Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
        
        # Insert multiple access entries using context functions
        {:ok, _access1} = AccessControl.set_user_access(%{
          user_id: user.id,
          entity_type: "test_entity",
          entity_id: 123,
          role_id: role.id
        })

        {:ok, _access2} = AccessControl.set_user_access(%{
          user_id: user.id,
          entity_type: "test_entity",
          entity_id: 456,
          role_id: role.id
        })

        access_list = AccessControl.get_user_access(user.id)
        assert length(access_list) == 2
        assert Enum.all?(access_list, fn access -> access.user_id == user.id end)
      end)
    end

    test "list_entity_access/0 returns all entity access entries", %{user: user, role: role} do
      # Use resilient test helper to handle potential DB connection issues
      XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        # Ensure we have ownership of the DB connection for this test
        Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo)
        
        # Insert access entry using context function
        {:ok, _access} = AccessControl.set_user_access(%{
          user_id: user.id,
          entity_type: "test_entity",
          entity_id: 123,
          role_id: role.id
        })

        access_list = AccessControl.list_entity_access()
        assert length(access_list) >= 1
      end)
    end

    test "has_access?/3 correctly checks user access", %{user: user, role: role} do
      # Use resilient test helper to handle potential DB connection issues
      XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        # Ensure we have ownership of the DB connection for this test
        case Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo) do
          :ok -> :ok
          {:already, :owner} -> :ok
        end
        
        # Set shared mode to ensure subprocesses can access the connection
        Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
        
        # Insert access entry using context function
        {:ok, _access} = AccessControl.set_user_access(%{
          user_id: user.id,
          entity_type: "test_entity",
          entity_id: 123,
          role_id: role.id
        })

        assert AccessControl.has_access?(user.id, "test_entity", 123) == true
        assert AccessControl.has_access?(user.id, "test_entity", 456) == false
        assert AccessControl.has_access?(user.id, "different_entity", 123) == false
      end)
    end

    test "delete_entity_access/1 removes access", %{user: user, role: role} do
      # Use resilient test helper to handle potential DB connection issues
      XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        # Ensure we have ownership of the DB connection for this test
        case Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo) do
          :ok -> :ok
          {:already, :owner} -> :ok
        end
        
        # Set shared mode to ensure subprocesses can access the connection
        Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
        
        # Insert access entry using context function
        {:ok, access} = AccessControl.set_user_access(%{
          user_id: user.id,
          entity_type: "test_entity",
          entity_id: 789,
          role_id: role.id
        })

        assert AccessControl.has_access?(user.id, "test_entity", 789) == true
        {:ok, _} = AccessControl.delete_entity_access(access.id)
        assert AccessControl.has_access?(user.id, "test_entity", 789) == false
      end)
    end
  end

  describe "products" do
    setup do
      # More resilient pattern for checking out the database connection
      case Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo) do
        :ok -> :ok
        {:already, :owner} -> :ok
        _ -> 
          # If checkout fails, try to ensure the repository is started
          {:ok, _} = Application.ensure_all_started(:ecto_sql)
          {:ok, _} = XIAM.Repo.start_link([])
          :ok = Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo)
      end
      
      # Always set sandbox mode to shared for this process
      Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
      
      # Generate timestamp for unique test data
      timestamp = System.system_time(:second)
      
      # Clean up existing test products
      import Ecto.Query
      Repo.delete_all(from p in Xiam.Rbac.Product, 
                      where: like(p.product_name, "%Test_Product_%") or
                             like(p.product_name, "%New_Product_%") or
                             like(p.product_name, "%List_Test_%") or
                             like(p.product_name, "%Get_Test_%") or
                             like(p.product_name, "%Update_Test_%") or
                             like(p.product_name, "%Delete_Test_%"))
      
      {:ok, timestamp: timestamp}
    end
    
    test "create_product/1 creates a new product", %{timestamp: timestamp} do
      product_name = "New_Product_#{timestamp}"
      attrs = %{
        product_name: product_name,
        description: "A new test product"
      }

      assert {:ok, product} = AccessControl.create_product(attrs)
      assert product.product_name == product_name
      assert product.description == "A new test product"
    end

    test "list_products/0 returns all products", %{timestamp: timestamp} do
      product_name = "List_Test_Product_#{timestamp}"
      
      # Create a product
      {:ok, _product} = AccessControl.create_product(%{
        product_name: product_name,
        description: "Product for testing list"
      })

      products = AccessControl.list_products()
      assert length(products) >= 1
      assert Enum.any?(products, fn p -> p.product_name == product_name end)
    end

    test "get_product/1 returns a specific product", %{timestamp: timestamp} do
      product_name = "Get_Test_Product_#{timestamp}"
      
      # Create a product
      {:ok, product} = AccessControl.create_product(%{
        product_name: product_name,
        description: "Product for testing get"
      })

      retrieved_product = AccessControl.get_product(product.id)
      assert retrieved_product.id == product.id
      assert retrieved_product.product_name == product_name
    end

    test "update_product/2 updates a product", %{timestamp: timestamp} do
      product_name = "Update_Test_Product_#{timestamp}"
      
      # Create a product
      {:ok, product} = AccessControl.create_product(%{
        product_name: product_name,
        description: "Original description"
      })

      attrs = %{description: "Updated description"}
      assert {:ok, updated_product} = AccessControl.update_product(product, attrs)
      assert updated_product.id == product.id
      assert updated_product.description == "Updated description"
    end

    test "delete_product/1 deletes a product", %{timestamp: timestamp} do
      product_name = "Delete_Test_Product_#{timestamp}"
      
      # Create a product
      {:ok, product} = AccessControl.create_product(%{
        product_name: product_name,
        description: "Product for testing delete"
      })

      assert {:ok, _} = AccessControl.delete_product(product)
      assert AccessControl.get_product(product.id) == nil
    end
  end

  describe "capabilities" do
    setup do
      # More resilient pattern for checking out the database connection
      case Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo) do
        :ok -> :ok
        {:already, :owner} -> :ok
        _ ->
          # If checkout fails, try to ensure the repository is started
          {:ok, _} = Application.ensure_all_started(:ecto_sql)
          {:ok, _} = XIAM.Repo.start_link([])
          :ok = Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo)
      end
      
      # Always set sandbox mode to shared for this process
      Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
      
      # Generate timestamp for unique test data
      timestamp = System.system_time(:second)
      
      # Clean up existing test capabilities and products
      import Ecto.Query
      Repo.delete_all(from c in Xiam.Rbac.Capability, 
                      where: like(c.name, "%test_capability_%"))
      
      Repo.delete_all(from p in Xiam.Rbac.Product, 
                      where: like(p.product_name, "%Capability_Test_%"))
      
      # Create a product for capabilities to reference with unique name
      {:ok, product} = AccessControl.create_product(%{
        product_name: "Capability_Test_Product_#{timestamp}",
        description: "Product for capability tests"
      })

      {:ok, product: product, timestamp: timestamp}
    end

    test "create_capability/1 creates a new capability", %{product: product, timestamp: timestamp} do
      capability_name = "new_capability_#{timestamp}"
      attrs = %{
        name: capability_name,
        description: "A new test capability",
        product_id: product.id
      }

      assert {:ok, capability} = AccessControl.create_capability(attrs)
      assert capability.name == capability_name
      assert capability.description == "A new test capability"
      assert capability.product_id == product.id
    end

    test "list_capabilities/0 returns all capabilities", %{product: product, timestamp: timestamp} do
      capability_name = "list_test_capability_#{timestamp}"
      
      # Create a capability
      {:ok, _capability} = AccessControl.create_capability(%{
        name: capability_name,
        description: "Capability for testing list",
        product_id: product.id
      })

      capabilities = AccessControl.list_capabilities()
      assert length(capabilities) >= 1
      assert Enum.any?(capabilities, fn c -> c.name == capability_name end)
    end

    test "get_capability/1 returns a specific capability", %{product: product, timestamp: timestamp} do
      capability_name = "get_test_capability_#{timestamp}"
      
      # Create a capability
      {:ok, capability} = AccessControl.create_capability(%{
        name: capability_name,
        description: "Capability for testing get",
        product_id: product.id
      })

      retrieved_capability = AccessControl.get_capability(capability.id)
      assert retrieved_capability.id == capability.id
      assert retrieved_capability.name == capability_name
    end

    test "update_capability/2 updates a capability", %{product: product, timestamp: timestamp} do
      capability_name = "update_test_capability_#{timestamp}"
      
      # Create a capability
      {:ok, capability} = AccessControl.create_capability(%{
        name: capability_name,
        description: "Original description",
        product_id: product.id
      })

      attrs = %{description: "Updated description"}
      assert {:ok, updated_capability} = AccessControl.update_capability(capability, attrs)
      assert updated_capability.id == capability.id
      assert updated_capability.description == "Updated description"
    end

    test "delete_capability/1 deletes a capability", %{product: product, timestamp: timestamp} do
      capability_name = "delete_test_capability_#{timestamp}"
      
      # Create a capability
      {:ok, capability} = AccessControl.create_capability(%{
        name: capability_name,
        description: "Capability for testing delete",
        product_id: product.id
      })

      assert {:ok, _} = AccessControl.delete_capability(capability)
      assert AccessControl.get_capability(capability.id) == nil
    end

    test "get_product_capabilities/1 returns capabilities for a product", %{product: product, timestamp: timestamp} do
      capability_name = "product_test_capability_#{timestamp}"
      
      # Create a capability
      {:ok, _capability} = AccessControl.create_capability(%{
        name: capability_name,
        description: "Capability for testing product capabilities",
        product_id: product.id
      })

      capabilities = AccessControl.get_product_capabilities(product.id)
      assert length(capabilities) >= 1
      assert Enum.any?(capabilities, fn c -> c.name == capability_name end)
    end
  end
end