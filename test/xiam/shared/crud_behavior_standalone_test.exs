defmodule XIAM.Shared.CRUDBehaviorStandaloneTest do
  use XIAM.DataCase
  
  # We'll define a dummy schema to test with
  defmodule TestSchema do
    use Ecto.Schema
    import Ecto.Changeset
    
    schema "test_schemas" do
      field :name, :string
      field :description, :string
      field :value, :integer
      
      timestamps()
    end
    
    def changeset(test_schema, attrs) do
      test_schema
      |> cast(attrs, [:name, :description, :value])
      |> validate_required([:name])
    end
  end
  
  # Create our test context module
  defmodule TestContext do
    use XIAM.Shared.CRUDBehavior,
      repo: XIAM.Repo,
      schema: TestSchema,
      preloads: [],
      pagination: true,
      search_field: :name,
      sort_fields: [:name, :value, :inserted_at]
      
    # Custom implementation of apply_filters
    def apply_filters(query, filters) do
      Enum.reduce(filters, query, fn
        {:name, name}, query when is_binary(name) ->
          where(query, [t], t.name == ^name)
          
        {:min_value, min}, query when is_integer(min) ->
          where(query, [t], t.value >= ^min)
          
        {:max_value, max}, query when is_integer(max) ->
          where(query, [t], t.value <= ^max)
          
        _, query -> query
      end)
    end
  end
  
  # Manually create the test table before running tests
  setup do
    # Check if the table exists and create it if not
    table_exists? = 
      try do
        Ecto.Adapters.SQL.query!(XIAM.Repo, "SELECT 1 FROM test_schemas LIMIT 1")
        true
      rescue
        _ -> false
      end
      
    unless table_exists? do
      Ecto.Adapters.SQL.query!(XIAM.Repo, """
      CREATE TABLE test_schemas (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        description TEXT,
        value INTEGER,
        inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP NOT NULL DEFAULT NOW()
      )
      """)
    end
    
    # Create some test data
    timestamp = System.system_time(:millisecond)
    
    {:ok, record1} = TestContext.create(%{
      name: "Test Record 1 #{timestamp}",
      description: "Description 1",
      value: 100
    })
    
    {:ok, record2} = TestContext.create(%{
      name: "Test Record 2 #{timestamp}",
      description: "Description 2",
      value: 200
    })
    
    {:ok, record3} = TestContext.create(%{
      name: "Different Record #{timestamp}",
      description: "Description 3",
      value: 50
    })
    
    # Return the test records
    %{
      record1: record1,
      record2: record2,
      record3: record3,
      timestamp: timestamp
    }
  end
  
  describe "CRUDBehavior list_all" do
    test "returns all records" do
      records = TestContext.list_all()
      assert length(records) >= 3
    end
    
    test "filters records by name", %{record1: record1, timestamp: _timestamp} do
      filtered = TestContext.list_all(%{name: record1.name})
      assert length(filtered) == 1
      assert hd(filtered).id == record1.id
    end
    
    test "filters records by value range", %{timestamp: _timestamp} do
      filtered = TestContext.list_all(%{min_value: 150})
      assert Enum.all?(filtered, fn r -> r.value >= 150 end)
      
      filtered = TestContext.list_all(%{max_value: 75})
      assert Enum.all?(filtered, fn r -> r.value <= 75 end)
      
      filtered = TestContext.list_all(%{min_value: 75, max_value: 150})
      assert Enum.all?(filtered, fn r -> r.value >= 75 && r.value <= 150 end)
    end
    
    test "supports pagination" do
      # Get first page with 1 item per page
      page1 = TestContext.list_all(%{}, %{page: 1, page_size: 1})
      
      # Verify pagination structure
      assert Map.has_key?(page1, :entries) || Map.has_key?(page1, :items)
      assert Map.has_key?(page1, :page_number) || Map.has_key?(page1, :page)
      assert Map.has_key?(page1, :page_size) || Map.has_key?(page1, :per_page)
      
      # Get second page
      page2 = TestContext.list_all(%{}, %{page: 2, page_size: 1})
      
      # Get entries from both pages
      entries1 = Map.get(page1, :entries) || Map.get(page1, :items)
      entries2 = Map.get(page2, :entries) || Map.get(page2, :items)
      
      # Verify we got different records
      assert length(entries1) == 1
      assert length(entries2) == 1
      assert hd(entries1).id != hd(entries2).id
    end
    
    test "supports searching", %{record3: record3, timestamp: _timestamp} do
      search_results = TestContext.list_all(%{search: "Different"})
      
      # Should find our "Different Record"
      assert Enum.any?(search_results, fn r -> r.id == record3.id end)
      
      # Shouldn't find records not matching search
      assert Enum.all?(search_results, fn r -> String.contains?(r.name, "Different") end)
    end
    
    test "supports sorting", %{timestamp: _timestamp} do
      # Sort by value ascending
      asc_value = TestContext.list_all(%{sort_by: :value, sort_order: :asc})
      values = Enum.map(asc_value, fn r -> r.value end)
      assert values == Enum.sort(values)
      
      # Sort by value descending
      desc_value = TestContext.list_all(%{sort_by: :value, sort_order: :desc})
      values = Enum.map(desc_value, fn r -> r.value end)
      assert values == Enum.sort(values, :desc)
    end
  end
  
  describe "CRUDBehavior get/1 and get!/1" do
    test "get/1 returns a record by ID", %{record1: record1} do
      assert TestContext.get(record1.id).id == record1.id
    end
    
    test "get/1 returns nil for nonexistent ID" do
      assert TestContext.get(999_999_999) == nil
    end
    
    test "get!/1 returns a record by ID", %{record1: record1} do
      assert TestContext.get!(record1.id).id == record1.id
    end
    
    test "get!/1 raises for nonexistent ID" do
      assert_raise Ecto.NoResultsError, fn ->
        TestContext.get!(999_999_999)
      end
    end
  end
  
  describe "CRUDBehavior create/1" do
    test "creates a record with valid attributes", %{timestamp: timestamp} do
      attrs = %{
        name: "New Test Record #{timestamp}",
        description: "New Description",
        value: 42
      }
      
      assert {:ok, record} = TestContext.create(attrs)
      assert record.name == attrs.name
      assert record.description == attrs.description
      assert record.value == attrs.value
    end
    
    test "returns error changeset with invalid attributes" do
      attrs = %{
        name: nil, # name is required
        description: "Invalid Record",
        value: 42
      }
      
      assert {:error, changeset} = TestContext.create(attrs)
      assert "can't be blank" in errors_on(changeset).name
    end
  end
  
  describe "CRUDBehavior update/2" do
    test "updates a record with valid attributes", %{record1: record1} do
      attrs = %{
        description: "Updated Description",
        value: 999
      }
      
      assert {:ok, updated} = TestContext.update(record1, attrs)
      assert updated.id == record1.id
      assert updated.description == "Updated Description"
      assert updated.value == 999
    end
    
    test "returns error changeset with invalid attributes", %{record1: record1} do
      attrs = %{
        name: nil # name is required
      }
      
      assert {:error, changeset} = TestContext.update(record1, attrs)
      assert "can't be blank" in errors_on(changeset).name
    end
  end
  
  describe "CRUDBehavior delete/1" do
    test "deletes a record", %{record2: record2} do
      assert {:ok, deleted} = TestContext.delete(record2)
      assert deleted.id == record2.id
      
      # Verify it's gone
      assert TestContext.get(record2.id) == nil
    end
  end
  
  describe "CRUDBehavior apply_sorting/3" do
    test "sorts by field when valid", %{timestamp: timestamp} do
      # Create extra records to ensure good sorting test
      {:ok, _} = TestContext.create(%{name: "AAA Record #{timestamp}", value: 1})
      {:ok, _} = TestContext.create(%{name: "ZZZ Record #{timestamp}", value: 999})
      
      # Sort by name ascending
      records = TestContext.list_all(%{sort_by: :name, sort_order: :asc})
      names = Enum.map(records, & &1.name)
      
      # Check first few records are in order
      first_few = Enum.take(names, 2)
      assert Enum.sort(first_few) == first_few
      
      # Sort by name descending
      records = TestContext.list_all(%{sort_by: :name, sort_order: :desc})
      names = Enum.map(records, & &1.name)
      
      # Check first few records are in reverse order
      first_few = Enum.take(names, 2)
      assert Enum.sort(first_few, :desc) == first_few
    end
    
    test "ignores sorting with invalid field", %{timestamp: _timestamp} do
      # The resulting query should not have ORDER BY when invalid field given
      # We can't directly check SQL, but we can verify it doesn't error
      records = TestContext.list_all(%{sort_by: :invalid_field, sort_order: :asc})
      assert is_list(records)
    end
  end
end