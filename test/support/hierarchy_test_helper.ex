defmodule XIAM.HierarchyTestHelper do
  @moduledoc """
  Helper functions for testing the XIAM.Hierarchy module and its submodules.
  Implements resilient patterns from the test improvement strategy to avoid flaky tests.
  """

  alias XIAM.Repo
  alias XIAM.Hierarchy.Node

  @doc """
  Ensures all applications required for hierarchy tests are started.
  Should be called at the beginning of each test.
  """
  def ensure_applications_started do
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    {:ok, _} = Application.ensure_all_started(:postgrex)
    :ok
  end

  @doc """
  Sets up a connection with shared mode to avoid ownership errors.
  """
  def setup_resilient_connection do
    Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
    
    # Ensure ETS tables exist
    XIAM.ETSTestHelper.ensure_ets_tables_exist()
    
    :ok
  end
  
  @doc """
  Creates a unique identifier with timestamp and random component
  to avoid uniqueness constraint violations.
  """
  def unique_id(prefix \\ "") do
    "#{prefix}#{System.system_time(:millisecond)}_#{:rand.uniform(100_000)}"
  end
  
  @doc """
  Sanitizes a string to be used in paths.
  Converts to lowercase and replaces non-alphanumeric characters with underscores.
  """
  def sanitize_for_path(string) do
    string |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "_")
  end
  
  @doc """
  Creates a node directly using Repo operations to avoid connection ownership issues.
  
  ## Options
  - :name - Node name (required)
  - :node_type - Node type, defaults to "company"
  - :parent_id - ID of parent node, defaults to nil (root node)
  - :metadata - Node metadata, defaults to %{"key" => "value"}
  - :path - Override the automatically generated path
  """
  def create_test_node(opts \\ []) do
    name = Keyword.fetch!(opts, :name)
    node_type = Keyword.get(opts, :node_type, "company")
    parent_id = Keyword.get(opts, :parent_id)
    metadata = Keyword.get(opts, :metadata, %{"key" => "value"})
    
    # Generate path based on name, or use provided path
    path = case Keyword.get(opts, :path) do
      nil ->
        if parent_id do
          parent = Repo.get!(Node, parent_id)
          "#{parent.path}.#{sanitize_for_path(name)}"
        else
          sanitize_for_path(name)
        end
      custom_path -> custom_path
    end
    
    # Create node directly
    %Node{
      name: name,
      node_type: node_type,
      parent_id: parent_id,
      path: path,
      metadata: metadata
    } |> Repo.insert!()
  end
  
  @doc """
  Execute a database operation in a transaction to maintain connection ownership.
  Returns {:ok, result} on success or {:error, reason} on failure.
  """
  def execute_in_transaction(fun) when is_function(fun, 0) do
    Repo.transaction(fn -> fun.() end)
  end
  
  @doc """
  Creates a test node hierarchy for access tests with a company, department, and team.
  Returns {:ok, %{company: company, department: department, team: team, user: user}}
  """
  def create_test_hierarchy_with_user do
    user_email = "test_#{unique_id()}@example.com"
    
    # Use the XIAM.TestHelpers implementation which creates test users directly
    # without going through the full auth flow
    {:ok, user} = XIAM.TestHelpers.create_test_user(%{
      email: user_email
    })
    
    # Create company
    company = create_test_node(
      name: "Company #{unique_id()}",
      node_type: "company"
    )
    
    # Create department under company
    department = create_test_node(
      name: "Department #{unique_id()}",
      node_type: "department",
      parent_id: company.id
    )
    
    # Create team under department
    team = create_test_node(
      name: "Team #{unique_id()}",
      node_type: "team",
      parent_id: department.id
    )
    
    {:ok, %{
      company: company,
      department: department,
      team: team,
      user: user
    }}
  end
end
