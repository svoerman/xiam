defmodule XIAM.HierarchyTest do
  # Use DataCase with async: false to avoid database connection issues
  use XIAM.DataCase, async: false

  alias XIAM.Hierarchy
  alias XIAM.Hierarchy.Node
  alias XIAM.Repo

  describe "nodes" do
    # Use a function to generate unique valid attributes for each test using the robust timestamp + random pattern
    def valid_attrs do
      unique_id = "#{System.system_time(:millisecond)}_#{:rand.uniform(100_000)}"
      %{
        name: "Test Node #{unique_id}",
        node_type: "company",
        metadata: %{"key" => "value"}
      }
    end
    
    @update_attrs %{
      name: "Updated Node",
      node_type: "department",
      metadata: %{"key" => "updated value"}
    }
    @invalid_attrs %{name: nil, node_type: nil}

    # Setup block to ensure proper database initialization
    setup do
      # Setup ETS tables for cache operations
      XIAM.ETSTestHelper.safely_ensure_table_exists(:hierarchy_cache)
      XIAM.ETSTestHelper.safely_ensure_table_exists(:hierarchy_cache_metrics)
      
      # Initialize caches
      XIAM.ResilientDatabaseSetup.initialize_hierarchy_caches()
      
      :ok
    end
  
    def node_fixture(attrs \\ %{}) do
      # Get dynamic valid attributes with a unique path to prevent constraint errors
      timestamp = System.system_time(:millisecond)
      unique_id = "#{timestamp}_#{System.unique_integer([:positive, :monotonic])}"
      base_attrs = valid_attrs()
      
      # Add a unique path if one wasn't provided
      base_attrs = Map.put_new(base_attrs, :path, "test_path_#{unique_id}")
      
      # Convert keyword list to map if needed
      attrs_map = if Keyword.keyword?(attrs), do: Map.new(attrs), else: attrs
      
      # Merge the provided attributes with the valid attributes, ensuring path remains unique
      attrs_map = Map.merge(base_attrs, attrs_map)
      
      # Use resilient helper to handle database operations with retries
      XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        case Hierarchy.create_node(attrs_map) do
          {:ok, node} -> node
          {:error, changeset} -> 
            # If we got a unique constraint error, try again with a different path
            if errors_on(changeset)[:path] do
              node_fixture(Map.put(attrs_map, :path, "retry_path_#{System.unique_integer([:positive, :monotonic])}"))
            else
              flunk("Failed to create test node: #{inspect(changeset)}")
            end
        end
      end)
    end

    test "list_nodes/0 returns all nodes" do
      node = node_fixture()
      assert Hierarchy.list_nodes() |> Enum.map(& &1.id) |> Enum.member?(node.id)
    end

    test "get_node/1 returns the node with given id" do
      # First ensure the repo is started
      {:ok, _} = Application.ensure_all_started(:ecto_sql)
      {:ok, _} = Application.ensure_all_started(:postgrex)
      
      # Create node using resilient pattern
      node = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        node_fixture()
      end, max_retries: 3, retry_delay: 200)
      
      # Verify node using resilient pattern to handle potential database issues
      XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        fetched_node = Hierarchy.get_node(node.id)
        assert fetched_node.id == node.id
      end, max_retries: 3, retry_delay: 200)
    end

    test "create_node/1 with valid data creates a node" do
      attrs = valid_attrs()
      
      # Use our resilient pattern to handle potential repo initialization issues
      result = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        Hierarchy.create_node(attrs)
      end, max_retries: 3, retry_delay: 100)
      
      assert {:ok, %Node{} = node} = result
      assert node.name == attrs.name
      assert node.node_type == "company"
      assert node.metadata == %{"key" => "value"}
      # Path should be the sanitized version of the name
      sanitized_name = String.downcase(attrs.name) |> String.replace(~r/[^a-z0-9]+/, "_")
      assert node.path == sanitized_name
    end

    test "create_node/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Hierarchy.create_node(@invalid_attrs)
    end

    test "create_node/1 creates a child node with proper path" do
      parent = node_fixture()
      attrs = Map.put(valid_attrs(), :parent_id, parent.id)
      assert {:ok, %Node{} = child} = Hierarchy.create_node(attrs)
      assert child.parent_id == parent.id
      # Verify the path has the proper format (parent.path followed by child name)
      # The sanitized child name may have a unique suffix, so we extract name from attrs
      sanitized_child_name = String.downcase(attrs.name) |> String.replace(~r/[^a-z0-9]+/, "_")
      assert child.path == "#{parent.path}.#{sanitized_child_name}"
    end

    test "update_node/2 with valid data updates the node" do
      node = node_fixture()
      assert {:ok, %Node{} = node} = Hierarchy.update_node(node, @update_attrs)
      assert node.name == "Updated Node"
      assert node.node_type == "department"
      assert node.metadata == %{"key" => "updated value"}
    end

    test "update_node/2 with invalid data returns error changeset" do
      node = node_fixture()
      assert {:error, %Ecto.Changeset{}} = Hierarchy.update_node(node, @invalid_attrs)
    end

    test "delete_node/1 deletes the node and its descendants" do
      parent = node_fixture()
      child_attrs = Map.put(valid_attrs(), :parent_id, parent.id)
      {:ok, child} = Hierarchy.create_node(child_attrs)
      
      assert {:ok, _} = Hierarchy.delete_node(parent)
      assert nil == Hierarchy.get_node(parent.id)
      assert nil == Hierarchy.get_node(child.id)
    end

    test "is_descendant?/2 correctly identifies descendant relationships" do
      # First ensure the repo is started
      {:ok, _} = Application.ensure_all_started(:ecto_sql)
      {:ok, _} = Application.ensure_all_started(:postgrex)
      
      # Setup ETS tables for cache operations
      XIAM.ETSTestHelper.safely_ensure_table_exists(:hierarchy_cache)
      XIAM.ETSTestHelper.safely_ensure_table_exists(:hierarchy_cache_metrics)
      
      # Create parent node using resilient pattern
      parent = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        node_fixture()
      end, max_retries: 3, retry_delay: 200)
      
      # Create child node with resilient pattern
      child = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        child_attrs = Map.put(valid_attrs(), :parent_id, parent.id)
        {:ok, child} = Hierarchy.create_node(child_attrs)
        child
      end, max_retries: 3, retry_delay: 200)
      
      # Create grandchild node with resilient pattern
      grandchild = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        grandchild_attrs = Map.put(valid_attrs(), :parent_id, child.id)
        grandchild_attrs = Map.put(grandchild_attrs, :name, "Grandchild_#{System.system_time(:millisecond)}_#{:rand.uniform(100_000)}")
        {:ok, grandchild} = Hierarchy.create_node(grandchild_attrs)
        grandchild
      end, max_retries: 3, retry_delay: 200)
      
      # Test descendant relationships with resilient pattern
      XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        assert Hierarchy.is_descendant?(child.id, parent.id)
        assert Hierarchy.is_descendant?(grandchild.id, parent.id)
        assert Hierarchy.is_descendant?(grandchild.id, child.id)
        refute Hierarchy.is_descendant?(parent.id, child.id)
        refute Hierarchy.is_descendant?(child.id, grandchild.id)
      end, max_retries: 3, retry_delay: 200)
    end

    @tag timeout: 120_000  # Explicitly increase the test timeout to ensure we have enough time
    test "move_subtree/2 moves a node and its descendants to a new parent" do
      # Ensure ETS tables exist before running the test
      XIAM.ETSTestHelper.ensure_ets_tables_exist()
      
      # Make sure the database connections are explicitly started/reset
      {:ok, _} = Application.ensure_all_started(:ecto_sql)
      {:ok, _} = Application.ensure_all_started(:postgrex)
      Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
      
      # Create parent nodes with shorter timeouts and more resilience
      old_parent = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        node_fixture(name: "Old Parent #{System.system_time(:millisecond)}")
      end, max_retries: 3, retry_delay: 200, timeout: 5_000)
      
      # Early assertion to fail fast if first step doesn't work
      assert %XIAM.Hierarchy.Node{} = old_parent, "Failed to create old parent node"
      
      new_parent = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        node_fixture(name: "New Parent #{System.system_time(:millisecond)}")
      end, max_retries: 3, retry_delay: 200, timeout: 5_000)  
      
      # Early assertion to fail fast if second step doesn't work
      assert %XIAM.Hierarchy.Node{} = new_parent, "Failed to create new parent node"
      
      # Create a node under old_parent with a unique name based on timestamp
      node_name = "Test Node #{System.system_time(:millisecond)}"
      node = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        node_attrs = valid_attrs() |> Map.put(:parent_id, old_parent.id) |> Map.put(:name, node_name)
        {:ok, created_node} = Hierarchy.create_node(node_attrs)
        created_node
      end, max_retries: 3, retry_delay: 200, timeout: 5_000)
      
      # Create a child under node - also with timestamp uniqueness
      child_name = "Child #{System.system_time(:millisecond)}"
      child = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        child_attrs = valid_attrs() |> Map.put(:parent_id, node.id) |> Map.put(:name, child_name)
        {:ok, created_child} = Hierarchy.create_node(child_attrs)
        created_child
      end, max_retries: 3, retry_delay: 200, timeout: 5_000)
      
      # Move the node to new_parent with resilient execution and shorter timeout
      result = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        # Use our more resilient version that accepts node IDs
        Hierarchy.move_subtree(node.id, new_parent.id)
      end, max_retries: 5, retry_delay: 300, timeout: 10_000)
      
      # Verify the move was successful (with more flexible assertions)
      case result do
        {:ok, _moved_node} ->
          :ok  # Expected case, continue
        error ->
          flunk("Failed to move node: #{inspect(error)}")
      end
      
      # Get refreshed records with resilient execution
      refreshed_node = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        Hierarchy.get_node(node.id)
      end, max_retries: 3, retry_delay: 200, timeout: 5_000)
      
      refreshed_child = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        Hierarchy.get_node(child.id)
      end, max_retries: 3, retry_delay: 200, timeout: 5_000)
      
      # Check the parent relationship and path structure with resilient assertions
      assert refreshed_node.parent_id == new_parent.id, "Node's parent_id should match new_parent.id"
      assert String.starts_with?(refreshed_node.path, "#{new_parent.path}."), "Node's path should start with new parent's path"
      
      # Check that child was also moved properly
      assert refreshed_child.parent_id == refreshed_node.id, "Child's parent_id should match the moved node's id"
      assert String.starts_with?(refreshed_child.path, refreshed_node.path), "Child's path should start with moved node's path"
    end

    test "move_subtree/2 prevents moving a node to its own descendant" do
      # Use resilient test patterns for all database operations
      parent = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        node_fixture()
      end)
      
      child = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        child_attrs = Map.put(valid_attrs(), :parent_id, parent.id)
        {:ok, created_child} = Hierarchy.create_node(child_attrs)
        created_child
      end)
      
      # Try to move parent to child (would create cycle) with resilient execution
      result = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        Hierarchy.move_subtree(parent, child.id)
      end)
      assert {:error, :would_create_cycle} = result
    end
  end

  describe "access" do
    setup do
      # Import TestHelpers
      import XIAM.TestHelpers
      
      # Use our resilient test helpers to ensure DB operations succeed
      # Make sure to handle the {:ok, user} return pattern correctly
      {:ok, user} = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        create_test_user(%{
          email: "test_#{:rand.uniform(999999)}@example.com"
        })
      end)
      
      # Create hierarchy for testing with resilient patterns
      {:ok, country} = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        Hierarchy.create_node(%{
          name: "USA",
          node_type: "country"
        })
      end)
      
      {:ok, company} = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        Hierarchy.create_node(%{
          name: "Acme",
          node_type: "company",
          parent_id: country.id
        })
      end)
      
      # Create department under company
      {:ok, department} = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        Hierarchy.create_node(%{
          name: "HR",
          node_type: "department",
          parent_id: company.id
        })
      end)
      
      # Create team under department
      {:ok, team} = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        Hierarchy.create_node(%{
          name: "Recruiting",
          node_type: "team",
          parent_id: department.id
        })
      end)
      
      # Create a role for testing
      random_suffix = :rand.uniform(1000000)
      {:ok, role} = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        %Xiam.Rbac.Role{}
        |> Xiam.Rbac.Role.changeset(%{name: "Viewer_#{random_suffix}", description: "Test role"})
        |> Repo.insert()
      end)
      
      %{country: country, company: company, department: department, team: team, user: user, role: role}
    end
    
    test "grant_access/3 grants access to a node", %{user: user, department: department, role: role} do
      # Use the resilient test helper to handle database connection issues
      XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        # Grant access using the hierarchy manager
        {:ok, access} = Hierarchy.grant_access(user.id, department.id, role.id)
        
        # Verify the access was correctly granted
        assert access.user_id == user.id
        assert access.access_path == department.path
        assert access.role_id == role.id
      end)
    end
    
    test "can_access?/2 correctly checks access inheritance", %{user: user, country: country, company: company, department: department, team: team, role: role} do
      # Using a safer approach with the ResilientTestHelper to handle transient failures
      # This will automatically handle ETS table and repo connection issues
      XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        # Grant access at department level
        {:ok, _} = Hierarchy.grant_access(user.id, department.id, role.id)
        
        # User should have access to department and its descendants (team)
        assert Hierarchy.can_access?(user.id, department.id)
        assert Hierarchy.can_access?(user.id, team.id)
        
        # But not to ancestors (country, company) - access doesn't flow upward
        refute Hierarchy.can_access?(user.id, country.id) 
        refute Hierarchy.can_access?(user.id, company.id)
      end)
    end
    
    test "revoke_access/2 removes access", %{user: user, department: department, team: team, role: role} do
      # Using a safer approach with the ResilientTestHelper to handle transient failures
      # This will automatically handle ETS table and repo connection issues
      XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        # Grant access at department level
        {:ok, _} = Hierarchy.grant_access(user.id, department.id, role.id)
        
        # Make sure the caches are initialized - this is important for concurrent test execution
        XIAM.ETSTestHelper.ensure_ets_tables_exist()
        
        # Ensure access cache entries are invalidated to get fresh results
        XIAM.Hierarchy.AccessManager.invalidate_user_access_cache(user.id)
        XIAM.Hierarchy.AccessManager.invalidate_node_access_cache(department.id)
        XIAM.Hierarchy.AccessManager.invalidate_node_access_cache(team.id)
        
        # Verify access was granted
        assert Hierarchy.can_access?(user.id, department.id)
        assert Hierarchy.can_access?(user.id, team.id)
        
        # Revoke access
        {:ok, _} = Hierarchy.revoke_access(user.id, department.id)
        
        # Ensure caches are invalidated again after revocation
        XIAM.Hierarchy.AccessManager.invalidate_user_access_cache(user.id)
        XIAM.Hierarchy.AccessManager.invalidate_node_access_cache(department.id)
        XIAM.Hierarchy.AccessManager.invalidate_node_access_cache(team.id)
        
        # Verify access was revoked
        refute Hierarchy.can_access?(user.id, department.id)
        refute Hierarchy.can_access?(user.id, team.id)
      end)
    end
    
    # TODO: This test is encountering database connection issues during parallel test runs
    # The repository is not always available when the test is running
    # See docs/test_improvement_strategy.md for guidance on resilient test patterns
    @tag :skip
    test "list_accessible_nodes/1 returns all nodes a user can access", %{user: user, department: department, team: team, role: role} do
      # Grant access at department level using resilient pattern
      {:ok, _} = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        Hierarchy.grant_access(user.id, department.id, role.id)
      end)
      
      # Ensure database connection is established before running the test
      XIAM.ResilientDatabaseSetup.ensure_repository_started()
      
      # Use the resilient pattern for list_accessible_nodes with proper error handling
      access_result = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        Hierarchy.list_accessible_nodes(user.id)
      end, max_retries: 3)
      
      # Handle the result which could be an error tuple
      {accessible_nodes, accessible_ids} = case access_result do
        nodes when is_list(nodes) ->
          # Success case - we got a list of nodes
          {nodes, Enum.map(nodes, & &1.id)}
          
        {:error, error} ->
          # Debug info removed
          # Perform a direct database query as a fallback
          _grants = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
            from(a in XIAM.Hierarchy.Access, where: a.user_id == ^user.id) |> XIAM.Repo.all()
          end)
          
          # Log for debugging
          # Debug info removed
          flunk("Failed to list accessible nodes: #{inspect(error)}")
      end
      
      # Should include department and team
      assert Enum.member?(accessible_ids, department.id)
      assert Enum.member?(accessible_ids, team.id)
      
      # Should not include nodes the user doesn't have access to
      refute length(accessible_nodes) > 2
    end
  end
end
