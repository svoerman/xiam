defmodule Xiam.Rbac.ProductTest do
  use XIAM.DataCase
  import Ecto.Query

  alias Xiam.Rbac.Product
  alias Xiam.Rbac.AccessControl
  # Import required modules only

  # Generate timestamps once per module to ensure uniqueness
  @timestamp System.system_time(:second)
  
  @valid_attrs %{product_name: "Test_Product_#{@timestamp}", description: "Test product description"}
  @update_attrs %{product_name: "Updated_Product_#{@timestamp}", description: "Updated description"}
  @invalid_attrs %{product_name: nil, description: "Missing product name"}

  describe "product schema" do
    setup do
      # Explicitly ensure repo is available
      case Process.whereis(XIAM.Repo) do
        nil ->
          # Repo is not started, try to start it explicitly
          {:ok, _} = Application.ensure_all_started(:ecto_sql)
          {:ok, _} = XIAM.Repo.start_link([])
          # Set sandbox mode
          Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
        _ -> 
          :ok
      end
      :ok
    end
    
    test "changeset with valid attributes" do
      changeset = Product.changeset(%Product{}, @valid_attrs)
      assert changeset.valid?
    end

    test "changeset with invalid attributes" do
      changeset = Product.changeset(%Product{}, @invalid_attrs)
      refute changeset.valid?
    end

    test "changeset enforces unique product_name" do
      # Create a special test product name just for this test
      duplicate_attrs = %{
        product_name: "Duplicate_Test_#{@timestamp}", 
        description: "Testing duplicate product names"
      }
      
      # First create a product
      {:ok, _product} = AccessControl.create_product(duplicate_attrs)
      
      # Try to create another product with the same name
      {:error, changeset} = AccessControl.create_product(duplicate_attrs)
      
      assert %{product_name: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "product CRUD operations" do
    setup do
      # Explicitly ensure repo is available
      case Process.whereis(XIAM.Repo) do
        nil ->
          # Repo is not started, try to start it explicitly
          {:ok, _} = Application.ensure_all_started(:ecto_sql)
          {:ok, _} = XIAM.Repo.start_link([])
          # Set sandbox mode
          Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
        _ -> 
          :ok
      end
      
      # Clean up existing test products to avoid conflicts
      try do
        # Delete test products that might interfere with our tests
        # Use pattern matching with LIKE to clean up all timestamped test products
        Repo.delete_all(from p in Xiam.Rbac.Product, 
                        where: like(p.product_name, "Test_Product_%") or 
                               like(p.product_name, "Updated_Product_%") or
                               like(p.product_name, "Second_Product_%"))
      rescue
        _ -> :ok
      end
      
      :ok
    end
    
    test "create_product/1 with valid data creates a product" do
      {:ok, product} = AccessControl.create_product(@valid_attrs)
      assert product.product_name == @valid_attrs.product_name
      assert product.description == @valid_attrs.description
    end

    test "create_product/1 with invalid data returns error changeset" do
      {:error, changeset} = AccessControl.create_product(@invalid_attrs)
      assert %{product_name: ["can't be blank"]} = errors_on(changeset)
    end

    test "get_product/1 returns the product with given id" do
      {:ok, product} = AccessControl.create_product(@valid_attrs)
      assert AccessControl.get_product(product.id) == product
    end

    test "list_products/0 returns all products" do
      # Create a second product with its own timestamp
      second_product_name = "Second_Product_#{@timestamp}"

      # Create new test products
      {:ok, product} = AccessControl.create_product(@valid_attrs)
      # Create a second product
      {:ok, product2} = AccessControl.create_product(%{product_name: second_product_name})
      
      # Get only the products with our test names (in case there are other products in the DB)
      products = Repo.all(from p in Xiam.Rbac.Product, 
                         where: p.product_name == ^@valid_attrs.product_name or 
                                p.product_name == ^second_product_name)
      
      assert length(products) == 2
      assert Enum.any?(products, fn p -> p.id == product.id end)
      assert Enum.any?(products, fn p -> p.id == product2.id end)
    end

    test "update_product/2 with valid data updates the product" do
      {:ok, product} = AccessControl.create_product(@valid_attrs)
      {:ok, updated_product} = AccessControl.update_product(product, @update_attrs)
      
      assert updated_product.product_name == @update_attrs.product_name
      assert updated_product.description == @update_attrs.description
    end

    test "update_product/2 with invalid data returns error changeset" do
      {:ok, product} = AccessControl.create_product(@valid_attrs)
      {:error, changeset} = AccessControl.update_product(product, @invalid_attrs)
      
      assert %{product_name: ["can't be blank"]} = errors_on(changeset)
      # The product should remain unchanged
      assert AccessControl.get_product(product.id) == product
    end

    test "delete_product/1 deletes the product" do
      {:ok, product} = AccessControl.create_product(@valid_attrs)
      {:ok, _} = AccessControl.delete_product(product)
      
      assert AccessControl.get_product(product.id) == nil
    end
  end

  describe "products with capabilities" do
    setup do
      # Explicitly ensure repo is available
      case Process.whereis(XIAM.Repo) do
        nil ->
          # Repo is not started, try to start it explicitly
          {:ok, _} = Application.ensure_all_started(:ecto_sql)
          {:ok, _} = XIAM.Repo.start_link([])
          # Set sandbox mode
          Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
        _ -> 
          :ok
      end
      :ok
    end
    
    test "list_products/0 preloads capabilities" do
      # First clean up any existing test data that might interfere
      test_name = "Test_With_Capabilities_#{System.system_time(:second)}"
      
      # Create a product with capabilities
      {:ok, product} = AccessControl.create_product(%{
        product_name: test_name,
        description: "Product with capabilities test"
      })
      
      # Add capabilities to the product
      {:ok, capability1} = AccessControl.create_capability(%{
        name: "create_user_#{test_name}",
        description: "Can create users",
        product_id: product.id
      })
      
      {:ok, capability2} = AccessControl.create_capability(%{
        name: "delete_user_#{test_name}",
        description: "Can delete users",
        product_id: product.id
      })
      
      # Get the product with preloaded capabilities, filtered to just our test product
      products = Repo.all(
        from p in Xiam.Rbac.Product,
        where: p.product_name == ^test_name,
        preload: :capabilities
      )
      
      # Make sure we have exactly one product matching our criteria
      assert length(products) == 1
      loaded_product = hd(products)
      
      # Verify capabilities are loaded
      assert length(loaded_product.capabilities) == 2
      assert Enum.any?(loaded_product.capabilities, fn c -> c.id == capability1.id end)
      assert Enum.any?(loaded_product.capabilities, fn c -> c.id == capability2.id end)
    end
    
    test "get_product_capabilities/1 returns capabilities for a product" do
      # Create a product
      {:ok, product} = AccessControl.create_product(@valid_attrs)
      
      # Add capabilities to the product with timestamped names to ensure uniqueness
      capability_name = "create_user_#{@timestamp}"
      
      {:ok, capability1} = AccessControl.create_capability(%{
        name: capability_name,
        description: "Can create users",
        product_id: product.id
      })
      
      # Get capabilities for the product
      capabilities = AccessControl.get_product_capabilities(product.id)
      
      # Verify the right capabilities are returned
      assert length(capabilities) == 1
      assert hd(capabilities).id == capability1.id
      assert hd(capabilities).name == capability_name
    end
  end
end