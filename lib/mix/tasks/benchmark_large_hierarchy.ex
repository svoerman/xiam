defmodule Mix.Tasks.Benchmark.LargeHierarchy do
  use Mix.Task
  
  @shortdoc "Run a large-scale hierarchy access benchmark with 100,000 nodes"
  
  @moduledoc """
  Runs a large-scale performance benchmark for the hierarchical access control system,
  creating a hierarchy with approximately 100,000 nodes.

  ## Usage
  
  Run the default benchmark with 100,000 nodes:
  
      mix benchmark.large_hierarchy
  
  Run with a custom node count:
  
      mix benchmark.large_hierarchy --nodes=50000
  """
  
  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [nodes: :integer])
    
    # Start the application
    Mix.Task.run("app.start")
    
    # Get the target node count
    node_count = opts[:nodes] || 100_000
    
    # Run the benchmark
    XIAM.Benchmarks.LargeHierarchyBenchmark.run_large_benchmark(node_count)
  end
end
