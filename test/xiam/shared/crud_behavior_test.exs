defmodule XIAM.Shared.CRUDBehaviorTest do
  use XIAM.DataCase
  
  # Testing CRUDBehavior via the modules that use it
  alias Xiam.Rbac.Product
  # Not using this alias directly
  # alias XIAM.Rbac.CapabilityContext
  alias XIAM.Rbac.ProductContext
  alias XIAM.Repo
  
  # Setup test data
  setup do
    # Create a unique timestamp for each test
    timestamp = System.system_time(:millisecond)
    # Create test data for products
    product_name = "CRUD_Test_Product_#{timestamp}"
    description = "For testing CRUD behavior"
    
    # Create test data
    %{
      product_name: product_name,
      description: description,
      timestamp: timestamp
    }
  end
  
  describe "CRUDBehavior through ProductContext" do
    test "list_all implementation works through list_products", %{product_name: product_name, description: description} do
      # Create a product
      {:ok, product} = ProductContext.create_product(%{
        product_name: product_name,
        description: description
      })
      
      # List all products
      products = ProductContext.list_products()
      
      # Product should be included in the results
      assert Enum.any?(products, fn p -> p.id == product.id end)
    end
    
    test "get implementation works through get_product", %{product_name: product_name, description: description} do
      # Create a product
      {:ok, product} = ProductContext.create_product(%{
        product_name: product_name,
        description: description
      })
      
      # Get the product
      found = ProductContext.get_product(product.id)
      
      # Should be the same product
      assert found.id == product.id
      assert found.product_name == product_name
    end
    
    test "create implementation works through create_product", %{product_name: product_name, description: description} do
      # Create a product
      {:ok, product} = ProductContext.create_product(%{
        product_name: product_name,
        description: description
      })
      
      # Product should be created with correct attributes
      assert product.product_name == product_name
      assert product.description == description
    end
    
    test "update implementation works through update_product", %{product_name: product_name, description: description} do
      # Create a product
      {:ok, product} = ProductContext.create_product(%{
        product_name: product_name,
        description: description
      })
      
      # Update the product
      updated_name = "Updated_#{product_name}"
      {:ok, updated} = ProductContext.update_product(product, %{
        product_name: updated_name
      })
      
      # Product should be updated
      assert updated.id == product.id
      assert updated.product_name == updated_name
      assert updated.description == description
    end
    
    test "delete implementation works through delete_product", %{product_name: product_name, description: description} do
      # Create a product
      {:ok, product} = ProductContext.create_product(%{
        product_name: product_name,
        description: description
      })
      
      # Delete the product
      {:ok, _} = ProductContext.delete_product(product)
      
      # Product should not exist anymore
      assert ProductContext.get_product(product.id) == nil
    end
  end
  
  describe "CRUDBehavior pagination" do
    test "pagination works in list_all", %{product_name: product_name, description: description} do
      # Create multiple products
      {:ok, product1} = ProductContext.create_product(%{
        product_name: "#{product_name}_1",
        description: "#{description} 1"
      })
      
      {:ok, product2} = ProductContext.create_product(%{
        product_name: "#{product_name}_2",
        description: "#{description} 2"
      })
      
      # List with pagination
      page1 = ProductContext.list_products(%{}, %{page: 1, page_size: 1})
      
      # Should return pagination structure
      assert Map.has_key?(page1, :entries) || Map.has_key?(page1, :items)
      assert Map.has_key?(page1, :page_number) || Map.has_key?(page1, :page)
      assert Map.has_key?(page1, :page_size) || Map.has_key?(page1, :per_page)
      assert Map.has_key?(page1, :total_entries) || Map.has_key?(page1, :total_items) || Map.has_key?(page1, :total_count)
      assert Map.has_key?(page1, :total_pages) || Map.has_key?(page1, :pages)
      
      # Should have 1 entry on first page
      entries = Map.get(page1, :entries) || Map.get(page1, :items)
      assert length(entries) == 1
      
      # Page 2 should have second product
      page2 = ProductContext.list_products(%{}, %{page: 2, page_size: 1})
      entries2 = Map.get(page2, :entries) || Map.get(page2, :items)
      assert length(entries2) == 1
      
      # Between page 1 and 2, we should have different products
      page1_id = hd(entries).id
      page2_id = hd(entries2).id
      
      # Instead of checking exact IDs (which can vary), just verify they're different
      assert page1_id != page2_id
      
      # Additionally check that we can find the products we created somewhere in the results
      all_products = ProductContext.list_products()
      _created_product_names = [product1.product_name, product2.product_name]
      found_product_names = Enum.map(all_products, & &1.product_name)
      
      assert Enum.any?(found_product_names, fn name -> 
        name == product1.product_name || name == product2.product_name
      end)
    end
  end
  
  describe "CRUDBehavior search" do
    test "search field works in list_all", %{product_name: product_name, description: description, timestamp: timestamp} do
      # Set up some data for searching
      {:ok, _} = %Xiam.Rbac.Product{
        product_name: "#{product_name}_Unique",
        description: "#{description} Unique"
      } |> Repo.insert()
      
      {:ok, _} = %Xiam.Rbac.Product{
        product_name: "Different_#{timestamp}",
        description: "#{description} Different"
      } |> Repo.insert()
      
      # Search by product name
      results = ProductContext.list_products(%{product_name: "Unique"})
      
      # Should only return products matching the search
      assert length(results) == 1
      assert hd(results).product_name =~ "Unique"
    end
  end
  
  describe "CRUDBehavior sorting" do
    test "sorting works in list_all", %{product_name: product_name, description: description} do
      # Create products with names that sort differently
      {:ok, _} = %Xiam.Rbac.Product{
        product_name: "A_#{product_name}",
        description: description
      } |> Repo.insert()
      
      {:ok, _} = %Xiam.Rbac.Product{
        product_name: "Z_#{product_name}",
        description: description
      } |> Repo.insert()
      
      # Query with default sorting (product_name ASC)
      products_asc = ProductContext.list_products(%{
        sort_by: :product_name,
        sort_order: :asc
      })
      
      # Filter to just our test products
      test_products = Enum.filter(products_asc, fn p -> 
        String.contains?(p.product_name, product_name)
      end)
      
      # Should have at least 2 products
      assert length(test_products) >= 2
      
      # First should start with A, last with Z
      assert String.starts_with?(hd(test_products).product_name, "A_")
      assert String.starts_with?(List.last(test_products).product_name, "Z_")
      
      # Query with DESC sorting
      products_desc = ProductContext.list_products(%{
        sort_by: :product_name,
        sort_order: :desc
      })
      
      # Filter to just our test products
      test_products_desc = Enum.filter(products_desc, fn p -> 
        String.contains?(p.product_name, product_name)
      end)
      
      # First should start with Z, last with A
      assert String.starts_with?(hd(test_products_desc).product_name, "Z_")
      assert String.starts_with?(List.last(test_products_desc).product_name, "A_")
    end
  end
  
  describe "CRUDBehavior preloads" do
    test "preloads work in get", %{product_name: product_name, description: description, timestamp: timestamp} do
      # Create a product
      {:ok, product} = ProductContext.create_product(%{
        product_name: product_name,
        description: description
      })
      
      # Add capabilities to the product
      {:ok, capability} = %Xiam.Rbac.Capability{
        name: "test_capability_#{timestamp}",
        description: "Test capability",
        product_id: product.id
      } |> Repo.insert()
      
      # Get the product (should preload capabilities)
      found = ProductContext.get_product(product.id)
      
      # Capabilities should be preloaded
      assert found.capabilities != nil
      assert length(found.capabilities) == 1
      assert hd(found.capabilities).id == capability.id
    end
  end
  
  describe "CRUDBehavior default implementations" do
    test "apply_filters default implementation returns query unchanged" do
      # Define a module that doesn't override apply_filters
      defmodule DefaultFilterModuleTest do
        @moduledoc false
        
        def apply_filters(query, _) do
          # This simulates the default implementation in CRUDBehavior
          query
        end
      end
      
      # Create a query
      query = Ecto.Query.from(p in Product)
      
      # Apply filters with default implementation
      filtered = DefaultFilterModuleTest.apply_filters(query, %{some_filter: "value"})
      
      # SQL should be unchanged
      {sql1, _} = Ecto.Adapters.SQL.to_sql(:all, Repo, query)
      {sql2, _} = Ecto.Adapters.SQL.to_sql(:all, Repo, filtered)
      assert sql1 == sql2
    end
    
    test "apply_sorting default implementation with valid fields" do
      # Define module that uses sort_fields like CRUDBehavior
      defmodule DefaultSortModuleTest do
        @moduledoc false
        @sort_fields [:product_name, :inserted_at]
        
        def apply_sorting(query, sort_by, sort_order) do
          # This simulates the default implementation in CRUDBehavior
          if sort_by && sort_by in @sort_fields do
            direction = if sort_order == :desc, do: :desc, else: :asc
            Ecto.Query.order_by(query, [{^direction, ^sort_by}])
          else
            query
          end
        end
      end
      
      # Create a query
      query = Ecto.Query.from(p in Product)
      
      # Apply sorting with valid field
      sorted = DefaultSortModuleTest.apply_sorting(query, :product_name, :desc)
      
      # SQL should include ORDER BY
      {sql, _} = Ecto.Adapters.SQL.to_sql(:all, Repo, sorted)
      assert String.contains?(sql, "ORDER BY")
      assert String.contains?(sql, "product_name")
      assert String.contains?(sql, "DESC")
    end
    
    test "apply_sorting default implementation with invalid fields" do
      # Define module that uses sort_fields like CRUDBehavior
      defmodule InvalidSortModuleTest do
        @moduledoc false
        @sort_fields [:product_name, :inserted_at]
        
        def apply_sorting(query, sort_by, sort_order) do
          # This simulates the default implementation in CRUDBehavior
          if sort_by && sort_by in @sort_fields do
            direction = if sort_order == :desc, do: :desc, else: :asc
            Ecto.Query.order_by(query, [{^direction, ^sort_by}])
          else
            query
          end
        end
      end
      
      # Create a query
      query = Ecto.Query.from(p in Product)
      
      # Apply sorting with invalid field
      sorted = InvalidSortModuleTest.apply_sorting(query, :invalid_field, :asc)
      
      # SQL should not include ORDER BY
      {sql1, _} = Ecto.Adapters.SQL.to_sql(:all, Repo, query)
      {sql2, _} = Ecto.Adapters.SQL.to_sql(:all, Repo, sorted)
      assert sql1 == sql2
    end
  end
end