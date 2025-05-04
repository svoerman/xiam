defmodule XIAM.Benchmarks.LargeHierarchyBenchmark do
  alias XIAM.Hierarchy
  alias XIAM.Users
  alias XIAM.Repo
  alias XIAM.Hierarchy.Node
  alias XIAM.Hierarchy.Access
  alias Xiam.Rbac.Role
  import Ecto.Query

  @doc """
  Run a large-scale benchmark with 100,000 nodes.
  This uses a wider, shallower tree structure and batch inserts for efficiency.
  """
  def run_large_benchmark(target_node_count \\ 100_000) do
    IO.puts("==========================================")
    IO.puts("LARGE-SCALE HIERARCHY BENCHMARK (#{target_node_count} NODES)")
    IO.puts("==========================================")
    
    # Calculate appropriate width and depth for the hierarchy
    # For 100,000 nodes, a width of 50 and depth of 3 gives approximately 127,550 nodes
    {width, depth} = calculate_dimensions(target_node_count)
    
    IO.puts("Configuration:")
    IO.puts("  - Target node count: #{target_node_count}")
    IO.puts("  - Tree width: #{width}")
    IO.puts("  - Tree depth: #{depth}")
    IO.puts("  - Estimated node count: #{trunc(calculate_node_count(width, depth))}")
    IO.puts("==========================================")
    
    # Clean up previous benchmark data
    IO.puts("\nCleaning up previous benchmark data...")
    Repo.delete_all(from(n in Node, where: n.name == "benchmark_root" or like(n.name, "node_%_%")))
    IO.puts("Cleanup complete.")
    
    # Create the large hierarchy
    IO.puts("\nGenerating large hierarchy (this may take a while)...")
    {time_ms, root} = :timer.tc(fn -> 
      generate_large_hierarchy(width, depth)
    end, :millisecond)
    
    IO.puts("Hierarchy generated in #{time_ms / 1000} seconds")
    
    # Count actual number of nodes
    node_count = Repo.aggregate(Node, :count, :id)
    IO.puts("Created #{node_count} nodes in total.")
    
    # Run access check benchmarks
    IO.puts("\nRunning access check benchmarks...")
    run_access_benchmarks(root)
    
    # Show timing differences by node depth
    IO.puts("\nTesting access check performance by tree depth...")
    test_access_by_depth(root, depth)
    
    # Run batch operation benchmark
    IO.puts("\nTesting batch operation performance...")
    test_batch_operations(root)
    
    IO.puts("\nBenchmark complete!")
  end
  
  # Calculate width and depth to approximately reach the target node count
  defp calculate_dimensions(target_node_count) do
    # For very large hierarchies, we want wider trees with less depth
    # to avoid excessive query depth
    cond do
      target_node_count <= 1_000 -> {10, 3}
      target_node_count <= 10_000 -> {20, 3}
      target_node_count <= 100_000 -> {50, 3}
      true -> {100, 3}
    end
  end
  
  defp calculate_node_count(width, depth) do
    # Sum of geometric series: (1-r^(n+1))/(1-r) for r≠1
    (1 - :math.pow(width, depth + 1)) / (1 - width)
  end

  defp generate_large_hierarchy(width, depth) do
    # Create root node
    {:ok, root} = Hierarchy.create_node(%{name: "benchmark_root", node_type: "organization"})
    
    # Create first level of children in a batch
    first_level_children = create_level_in_batch(root, width, 1)
    
    # Create second level for each first level node
    if depth >= 2 do
      second_level_children = 
        Enum.flat_map(first_level_children, fn node ->
          create_level_in_batch(node, width, 2)
        end)
      
      # Create third level if needed
      if depth >= 3 do
        _third_level = 
          Enum.flat_map(second_level_children, fn node ->
            create_level_in_batch(node, width, 3)
          end)
      end
    end
    
    root
  end
  
  # Create a level of children in a batch operation
  defp create_level_in_batch(parent, width, level) do
    IO.puts("  Creating level #{level} nodes (#{width} children per parent)...")
    
    # Create nodes in groups of 100 to avoid overwhelming the database
    batch_size = 100
    num_batches = ceil(width / batch_size)
    
    Enum.flat_map(1..num_batches, fn batch ->
      start_idx = (batch - 1) * batch_size + 1
      end_idx = min(batch * batch_size, width)
      
      # Create a batch of nodes
      nodes = Enum.map(start_idx..end_idx, fn i ->
        {:ok, node} = Hierarchy.create_node(%{
          name: "node_#{level}_#{i}",
          node_type: "department",
          parent_id: parent.id
        })
        node
      end)
      
      nodes
    end)
  end
  
  defp run_access_benchmarks(root) do
    # Get existing users
    users = Users.list_users() |> Enum.take(5)
    if Enum.empty?(users) do
      IO.puts("ERROR: No users found for testing.")
      exit(:normal)
    end
    
    # Grant some strategic access permissions
    user = hd(users)
    role = Repo.one(from(r in Role, limit: 1))
    
    # Check if access already exists
    existing_access = Repo.one(from(a in Access, 
        where: a.user_id == ^user.id and a.access_path == ^root.path))
        
    # Grant root access if it doesn't exist
    if is_nil(existing_access) do
      case %Access{}
           |> Access.changeset(%{user_id: user.id, access_path: root.path, role_id: role.id})
           |> Repo.insert() do
        {:ok, grant} -> 
          IO.puts("  Granted access to root node")
          grant
        {:error, changeset} ->
          IO.puts("  Error granting access: #{inspect(changeset.errors)}")
          # Return a dummy grant for the rest of the code to use
          %Access{user_id: user.id, access_path: root.path, role_id: role.id}
      end
    else
      IO.puts("  Using existing access grant")
      existing_access
    end
    
    # Get some test nodes at different depths
    [level1_node | _] = Repo.all(from(n in Node, 
                        where: fragment("nlevel(?::ltree)", n.path) == 2, 
                        limit: 1))
                        
    [level2_node | _] = Repo.all(from(n in Node, 
                        where: fragment("nlevel(?::ltree)", n.path) == 3, 
                        limit: 1))
                        
    # Get the deepest node
    [deepest_node | _] = Repo.all(from(n in Node, 
                          order_by: [desc: fragment("nlevel(?::ltree)", n.path)], 
                          limit: 1))
    
    # Test different access patterns
    
    # 1. Direct access to root (fastest)
    benchmark("Direct access to root node", fn ->
      Hierarchy.can_access?(user.id, root.id)
    end)
    
    # 2. Access to level 1 node
    benchmark("Access to level 1 node", fn ->
      Hierarchy.can_access?(user.id, level1_node.id)
    end)
    
    # 3. Access to level 2 node  
    benchmark("Access to level 2 node", fn ->
      Hierarchy.can_access?(user.id, level2_node.id)
    end)
    
    # Get path depth for logging
    path_depth_query = from(n in Node, 
                        where: n.id == ^deepest_node.id, 
                        select: fragment("nlevel(?::ltree)", n.path))
    path_depth = Repo.one(path_depth_query)
    
    # 4. Access to deepest node (should be most expensive)
    benchmark("Access to deepest node (#{path_depth} levels)", fn ->
      Hierarchy.can_access?(user.id, deepest_node.id)
    end)
  end
  
  defp test_access_by_depth(_root, max_depth) do
    # Get existing users
    user = hd(Users.list_users())
    
    # Test access performance at each level
    for depth <- 1..max_depth do
      depth_value = depth + 1
      [node | _] = Repo.all(from(n in Node, 
                    where: fragment("nlevel(?::ltree)", n.path) == ^depth_value, 
                    limit: 1))
                    
      # Skip if no node found at this depth
      if node do
        benchmark("Access check at depth #{depth}", fn ->
          Hierarchy.can_access?(user.id, node.id)
        end)
      end
    end
  end
  
  defp test_batch_operations(_root) do
    # Get first 5 users
    users = Users.list_users() |> Enum.take(5)
    user = hd(users)
    
    # Get 100 random nodes
    random_nodes = Repo.all(from(n in Node, order_by: fragment("RANDOM()"), limit: 100))
    
    # Test checking access to 100 nodes in sequence
    benchmark("Check access to 100 nodes sequentially", fn ->
      Enum.each(random_nodes, fn node ->
        Hierarchy.can_access?(user.id, node.id)
      end)
    end, single_run: true)
    
    # Test checking access to 100 nodes in parallel
    benchmark("Check access to 100 nodes in parallel (50 tasks)", fn ->
      random_nodes
      |> Enum.chunk_every(2)
      |> Enum.map(fn nodes ->
        Task.async(fn ->
          Enum.each(nodes, fn node ->
            Hierarchy.can_access?(user.id, node.id)
          end)
        end)
      end)
      |> Task.await_many(30_000)
    end, single_run: true)
  end
  
  defp benchmark(name, func, opts \\ []) do
    IO.puts("\n#{name}:")
    
    # Default options
    single_run = Keyword.get(opts, :single_run, false)
    iterations = if single_run, do: 1, else: 100
    
    # Warm up
    func.()
    
    # Measure multiple runs
    {total_μs, _results} = :timer.tc(fn ->
      Enum.map(1..iterations, fn _ -> func.() end)
    end)
    
    if single_run do
      IO.puts("  Total time: #{Float.round(total_μs / 1000, 2)} ms")
    else
      avg_μs = total_μs / iterations
      IO.puts("  Average: #{Float.round(avg_μs, 2)} μs (#{Float.round(avg_μs / 1000, 2)} ms)")
    end
  end
end
