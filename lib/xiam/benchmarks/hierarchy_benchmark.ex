defmodule XIAM.Benchmarks.HierarchyBenchmark do
  alias XIAM.Hierarchy
  alias XIAM.Users
  alias XIAM.Repo
  alias XIAM.Hierarchy.Node
  alias XIAM.Hierarchy.Access
  alias Xiam.Rbac.Role
  import Ecto.Query
  
  @doc """
  Generates a large hierarchy with the specified width and depth.
  Width determines how many children each node has.
  Depth determines how many levels deep the tree goes.
  """
  def generate_large_hierarchy(width \\ 5, depth \\ 5) do
    IO.puts("Generating a hierarchy with width=#{width}, depth=#{depth}...")
    IO.puts("This will create approximately #{calculate_node_count(width, depth)} nodes.")
    
    # Create root node
    {:ok, root} = Hierarchy.create_node(%{name: "benchmark_root", node_type: "organization"})
    
    # Recursively create children
    create_children(root, width, depth, 1)
    
    count = count_nodes()
    IO.puts("Created #{count} nodes in total.")
    
    # Return the root node
    root
  end
  
  defp calculate_node_count(width, depth) do
    # Sum of geometric series: (1-r^(n+1))/(1-r) for r≠1
    (1 - :math.pow(width, depth + 1)) / (1 - width)
  end
  
  defp count_nodes do
    Repo.aggregate(Node, :count, :id)
  end
  
  defp create_children(_parent, _width, max_depth, current_depth) when current_depth > max_depth, do: :ok
  defp create_children(parent, width, max_depth, current_depth) do
    # Create width number of children for this node
    Enum.each(1..width, fn i ->
      {:ok, child} = Hierarchy.create_node(%{
        name: "node_#{current_depth}_#{i}",
        node_type: "department",
        parent_id: parent.id
      })
      
      # Recursively create children for this child
      create_children(child, width, max_depth, current_depth + 1)
    end)
  end
  
  @doc """
  Creates test users and assigns access at strategic points in the hierarchy.
  Returns a map with users and nodes for testing.
  """
  def setup_access_grants(root, num_nodes \\ 3) do
    IO.puts("Setting up access grants using existing users...")
    
    # Get existing users from the database
    users = Users.list_users() |> Enum.take(5)
    
    if Enum.empty?(users) do
      IO.puts("\nERROR: No users found in database. Please create at least one user before running the benchmark.")
      exit(:normal)
    end
    
    IO.puts("Using #{length(users)} existing users for access grants")
    
    # Get nodes at different levels for granting access
    nodes = get_sample_nodes(root)
    
    # Grant access to each user at different levels
    Enum.each(users, fn user ->
      # Grant each user access to a selection of nodes
      Enum.take_random(nodes, num_nodes)
      |> Enum.each(fn node ->
        # Use direct Repo.insert to avoid undefined function errors
        role = Repo.one(from r in Role, limit: 1) # Get first role for demo purposes
        
        # Check if grant already exists to avoid uniqueness constraint errors
        existing = Repo.one(from a in Access, 
          where: a.user_id == ^user.id and a.access_path == ^node.path)
          
        if is_nil(existing) do
          case %Access{}
               |> Access.changeset(%{user_id: user.id, access_path: node.path, role_id: role.id})
               |> Repo.insert() do
            {:ok, _grant} -> 
              IO.puts("  Granted user #{user.email} access to node #{node.name}")
            {:error, changeset} ->
              IO.puts("  Error granting access: #{inspect(changeset.errors)}")
          end
        else
          IO.puts("  User #{user.email} already has access to #{node.name}")
        end
      end)
    end)
    
    %{
      users: users,
      nodes: nodes,
      root: root
    }
  end
  
  defp get_sample_nodes(root) do
    # Get the entire hierarchy
    all_nodes = [root | Hierarchy.get_descendants(root.id)]
    
    # Sample nodes from different parts of the hierarchy
    # This is more efficient than querying for each level separately
    sample_size = min(100, length(all_nodes))
    Enum.take_random(all_nodes, sample_size)
  end
  
  @doc """
  Runs a production-like load test simulating concurrent users accessing various nodes.
  
  Options:
  - :concurrent_users - Number of simultaneous users (default: 50)
  - :requests_per_user - Number of access checks per user (default: 20)
  - :depth - Depth of hierarchy tree (default: 4)
  - :width - Width of hierarchy tree (default: 4)
  """
  def run_production_test(opts \\ []) do
    # Default options
    concurrent_users = Keyword.get(opts, :concurrent_users, 50)
    requests_per_user = Keyword.get(opts, :requests_per_user, 20)
    depth = Keyword.get(opts, :depth, 4)
    width = Keyword.get(opts, :width, 4)
    
    total_requests = concurrent_users * requests_per_user
    
    IO.puts("==========================================")
    IO.puts("HIERARCHY ACCESS CONTROL PERFORMANCE TEST")
    IO.puts("==========================================")
    IO.puts("Configuration:")
    IO.puts("  - Concurrent users: #{concurrent_users}")
    IO.puts("  - Requests per user: #{requests_per_user}")
    IO.puts("  - Total requests: #{total_requests}")
    IO.puts("  - Hierarchy depth: #{depth}")
    IO.puts("  - Hierarchy width: #{width}")
    IO.puts("==========================================")
    
    # Generate the test hierarchy
    root = generate_large_hierarchy(width, depth)
    
    # Set up users and access grants
    test_data = setup_access_grants(root, concurrent_users)
    
    # Get all nodes for testing
    all_nodes = [root | Hierarchy.get_descendants(root.id)]
    IO.puts("Using #{length(all_nodes)} nodes for access testing")
    
    # Run the load test
    IO.puts("\nStarting load test with #{concurrent_users} concurrent users...")
    IO.puts("Each user will perform #{requests_per_user} access checks.")
    
    start_time = System.monotonic_time(:millisecond)
    
    # Create tasks for each user
    tasks = for user_idx <- 1..concurrent_users do
      Task.async(fn ->
        # Get the user
        user = Enum.at(test_data.users, rem(user_idx - 1, length(test_data.users)))
        
        # Run requests for this user
        for _ <- 1..requests_per_user do
          # Select a random node to check access for
          node = Enum.random(all_nodes)
          
          # Perform the access check
          Hierarchy.can_access?(user.id, node.id)
        end
      end)
    end
    
    # Wait for all tasks to complete
    Task.await_many(tasks, 60_000)
    
    end_time = System.monotonic_time(:millisecond)
    duration_ms = end_time - start_time
    duration_sec = duration_ms / 1000
    
    # Calculate metrics
    throughput = total_requests / duration_sec
    avg_latency = duration_ms / total_requests
    
    # Report results
    IO.puts("\nPerformance Test Results:")
    IO.puts("------------------------------------------")
    IO.puts("Completed #{total_requests} requests in #{Float.round(duration_sec, 2)} seconds")
    IO.puts("Throughput: #{Float.round(throughput, 2)} requests/second")
    IO.puts("Average latency: #{Float.round(avg_latency, 2)} ms per request")
    IO.puts("------------------------------------------")
    
    # Run detailed single-request performance tests
    run_detailed_benchmarks(test_data)
    
    # Run query analysis
    run_query_analysis(hd(test_data.users).id, hd(all_nodes).id)
    
    %{
      total_requests: total_requests,
      duration_sec: duration_sec,
      throughput: throughput,
      avg_latency: avg_latency
    }
  end
  
  defp run_detailed_benchmarks(test_data) do
    IO.puts("\nDetailed Single-Request Benchmarks:")
    IO.puts("------------------------------------------")
    
    # Sample user and nodes for detailed testing
    user = hd(test_data.users)
    
    # Test direct access (node where user has direct grant)
    # Find a node where this user has direct access
    direct_grants = from(a in Access, where: a.user_id == ^user.id) |> Repo.all()
    
    if length(direct_grants) > 0 do
      # Get node from access path
      access_path = hd(direct_grants).access_path
      direct_node = Repo.one(from n in Node, where: n.path == ^access_path)
      direct_node_id = direct_node.id
      
      benchmark("Direct access check", fn -> 
        Hierarchy.can_access?(user.id, direct_node_id)
      end)
    end
    
    # Test inherited access (child of node with direct grant)
    if length(direct_grants) > 0 do
      # Get node from access path
      access_path = hd(direct_grants).access_path
      direct_node = Repo.one(from n in Node, where: n.path == ^access_path)
      direct_node_id = direct_node.id
      children = Hierarchy.get_direct_children(direct_node_id)
      
      if length(children) > 0 do
        child_node = hd(children)
        benchmark("Inherited access check (1 level)", fn -> 
          Hierarchy.can_access?(user.id, child_node.id)
        end)
      end
    end
    
    # Test deep inherited access
    deep_node = get_deep_node(test_data.root)
    benchmark("Deep hierarchy access check", fn -> 
      Hierarchy.can_access?(user.id, deep_node.id)
    end)
    
    # Test denied access
    benchmark("Access denied check", fn -> 
      # Check access to a random node
      # Use the second user's access path but check with first user's ID
      other_user = Enum.at(test_data.users, 1)
      other_grants = from(a in Access, where: a.user_id == ^other_user.id) |> Repo.all()
      
      if length(other_grants) > 0 do
        # Get the node ID from the access path
        access_path = hd(other_grants).access_path
        other_node = Repo.one(from n in Node, where: n.path == ^access_path)
        
        # Check if our main user can access this other user's node (should be denied)
        Hierarchy.can_access?(user.id, other_node.id)
      else
        # Fallback if no grants for other user
        false
      end
    end)
  end
  
  defp get_deep_node(root) do
    # Go as deep as possible in the hierarchy
    descendants = Hierarchy.get_descendants(root.id)
    if length(descendants) > 0 do
      # Sort by path length to find the deepest node
      Enum.max_by(descendants, fn node -> 
        node.path |> String.split(".") |> length()
      end)
    else
      root
    end
  end
  
  defp benchmark(name, func) do
    IO.puts("\n#{name}:")
    
    # Warm up
    func.()
    
    # Measure multiple runs
    iterations = 100
    {total_μs, _results} = :timer.tc(fn ->
      Enum.map(1..iterations, fn _ -> func.() end)
    end)
    
    avg_μs = total_μs / iterations
    IO.puts("  Average: #{Float.round(avg_μs, 2)} μs (#{Float.round(avg_μs / 1000, 2)} ms)")
    
    # Test cached vs uncached if using a cache mechanism
    if function_exported?(XIAM.Hierarchy.AccessCache, :clear, 0) do
      try do
        # Try to clear cache
        :ok = apply(XIAM.Hierarchy.AccessCache, :clear, [])
        
        # First call (uncached)
        {uncached_μs, _} = :timer.tc(func)
        
        # Second call (should be cached)
        {cached_μs, _} = :timer.tc(func)
        
        IO.puts("  Uncached: #{uncached_μs} μs (#{Float.round(uncached_μs / 1000, 2)} ms)")
        IO.puts("  Cached: #{cached_μs} μs (#{Float.round(cached_μs / 1000, 2)} ms)")
        IO.puts("  Cache speedup: #{Float.round(uncached_μs / max(cached_μs, 1), 1)}x")
      rescue
        _ -> :ok
      end
    end
  end
  
  defp run_query_analysis(_user_id, _node_id) do
    IO.puts("\nQuery Analysis:")
    IO.puts("------------------------------------------")
    
    # Create a SQL query string directly for demonstration purposes
    # This is a simplified version that doesn't use the actual parameters
    sql = """
    EXPLAIN ANALYZE
    SELECT a.id FROM hierarchy_access AS a
    WHERE a.user_id = 1
    AND a.node_path @> (SELECT path FROM hierarchy_nodes WHERE id = 2)
    LIMIT 1
    """
    
    IO.puts("Access check query example:")
    IO.puts(sql)
    
    # Execute the EXPLAIN query
    result = Ecto.Adapters.SQL.query!(Repo, sql, [])
    
    IO.puts("\nQuery execution plan:")
    Enum.each(result.rows, fn row -> 
      IO.puts("  #{Enum.at(row, 0)}")
    end)
  end
end
