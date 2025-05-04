defmodule Mix.Tasks.Benchmark.Hierarchy do
  use Mix.Task
  import Ecto.Query
  
  @shortdoc "Run hierarchy access control performance benchmarks"
  
  @moduledoc """
  Runs performance benchmarks for the hierarchical access control system.
  
  ## Usage
  
  Run a default benchmark:
  
      mix benchmark.hierarchy
  
  Run with custom parameters:
  
      mix benchmark.hierarchy --users=30 --requests=50 --width=3 --depth=3
  
  Options:
  
  * `--users` - Number of concurrent users (default: 50)
  * `--requests` - Number of requests per user (default: 20)
  * `--width` - Width of the hierarchy (default: 4)
  * `--depth` - Depth of the hierarchy (default: 4)
  * `--small` - Use smaller test configuration (10 users, 10 requests, width 3, depth 3)
  * `--medium` - Use medium test configuration (30 users, 20 requests, width 4, depth 4)
  * `--large` - Use large test configuration (50 users, 50 requests, width 5, depth 4)
  """
  
  @impl Mix.Task
  def run(args) do
    # Parse command line args
    {opts, _, _} = OptionParser.parse(args, 
      strict: [
        users: :integer,
        requests: :integer,
        width: :integer,
        depth: :integer,
        small: :boolean,
        medium: :boolean,
        large: :boolean
      ]
    )
    
    # Start the application
    Mix.Task.run("app.start")
    
    # Set up the configuration based on preset or individual options
    config = cond do
      opts[:small] ->
        [concurrent_users: 10, requests_per_user: 10, width: 3, depth: 3]
      opts[:medium] ->
        [concurrent_users: 30, requests_per_user: 20, width: 4, depth: 4]
      opts[:large] ->
        [concurrent_users: 50, requests_per_user: 50, width: 5, depth: 4]
      true ->
        [
          concurrent_users: opts[:users] || 50,
          requests_per_user: opts[:requests] || 20,
          width: opts[:width] || 4,
          depth: opts[:depth] || 4
        ]
    end
    
    # Display the test configuration
    IO.puts("Running benchmark with configuration:")
    Enum.each(config, fn {key, value} ->
      IO.puts("  #{key}: #{value}")
    end)
    
    # Clean up any existing benchmark data first
    IO.puts("\nCleaning up previous benchmark data...")
    cleanup_benchmark_data()
    
    # Run the benchmark
    IO.puts("\nStarting benchmark...\n")
    XIAM.Benchmarks.HierarchyBenchmark.run_production_test(config)
  end
  
  # Clean up any existing benchmark data to start fresh
  defp cleanup_benchmark_data do
    alias XIAM.Repo
    alias XIAM.Hierarchy.Node
    
    # Delete all hierarchy nodes with benchmark names
    # This will cascade delete access grants through foreign keys
    Repo.delete_all(from n in Node, where: n.name == "benchmark_root" or like(n.name, "node_%_%"))
    
    # Log the cleanup
    IO.puts("Cleaned up any previous benchmark data")
  end
end
