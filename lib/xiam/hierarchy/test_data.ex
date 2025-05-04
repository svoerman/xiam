defmodule XIAM.Hierarchy.TestData do
  @moduledoc """
  Utility module for generating test hierarchies for performance testing.
  
  This module provides functions to generate large hierarchies for benchmarking
  and performance testing. It should only be used in development or test environments.
  """
  
  import Ecto.Query
  alias XIAM.Hierarchy
  alias XIAM.Repo
  alias XIAM.Users.User
  
  @doc """
  Generates a test hierarchy with the specified number of nodes.
  
  ## Options
    * `:node_count` - The number of nodes to generate (default: 10_000)
    * `:root_count` - The number of root nodes to create (default: 10)
    * `:max_depth` - Maximum depth of the hierarchy (default: 5)
    * `:types` - List of node types to use (default: ["company", "division", "department", "team", "project"])
    
  ## Returns
    * `{:ok, stats}` with statistics about the generated hierarchy
  """
  def generate_hierarchy(opts \\ []) do
    node_count = Keyword.get(opts, :node_count, 10_000)
    root_count = Keyword.get(opts, :root_count, 10)
    max_depth = Keyword.get(opts, :max_depth, 5)
    types = Keyword.get(opts, :types, ["company", "division", "department", "team", "project"])
    
    # Start transaction
    result = Repo.transaction(fn ->
      # Generate root nodes first
      root_ids = create_root_nodes(root_count, hd(types))
      
      # Track stats
      stats = %{
        total_nodes: root_count,
        by_level: %{0 => root_count},
        by_type: %{hd(types) => root_count}
      }
      
      # Now generate the rest of the hierarchy
      remaining = node_count - root_count
      {:ok, stats} = create_child_nodes(remaining, root_ids, types, max_depth, stats)
      
      stats
    end)
    
    case result do
      {:ok, stats} -> 
        IO.puts "Successfully generated hierarchy:"
        IO.puts "  Total nodes: #{stats.total_nodes}"
        IO.puts "  Nodes by level: #{inspect stats.by_level}"
        IO.puts "  Nodes by type: #{inspect stats.by_type}"
        {:ok, stats}
      {:error, error} -> 
        IO.puts "Error generating hierarchy: #{inspect error}"
        {:error, error}
    end
  end
  
  @doc """
  Creates test access grants for users in the hierarchy.
  
  ## Options
    * `:user_count` - The number of test users to create or use (default: 100)
    * `:grants_per_user` - Average number of access grants per user (default: 5)
    * `:role_id` - Role ID to use for grants (required)
    
  ## Returns
    * `{:ok, stats}` with statistics about the generated access grants
  """
  def generate_access_grants(opts \\ []) do
    user_count = Keyword.get(opts, :user_count, 100)
    grants_per_user = Keyword.get(opts, :grants_per_user, 5)
    role_id = Keyword.fetch!(opts, :role_id)
    
    # Get or create test users
    users = get_or_create_test_users(user_count)
    
    # Get all nodes
    nodes = Hierarchy.list_nodes()
    
    # If no nodes, return error
    if Enum.empty?(nodes) do
      {:error, "No nodes found in the hierarchy. Run generate_hierarchy first."}
    else
      # Start transaction
      result = Repo.transaction(fn ->
        # Track stats
        stats = %{total_grants: 0, users: length(users)}
        
        # For each user, create random grants
        stats = Enum.reduce(users, stats, fn user, acc ->
          # Determine number of grants for this user (randomize a bit)
          user_grants = max(1, grants_per_user + Enum.random(-2..2))
          
          # Select random nodes to grant access to
          grant_nodes = Enum.take_random(nodes, user_grants)
          
          # Create grants
          Enum.each(grant_nodes, fn node ->
            {:ok, _} = Hierarchy.grant_access(user.id, node.id, role_id)
          end)
          
          # Update stats
          %{acc | total_grants: acc.total_grants + length(grant_nodes)}
        end)
        
        stats
      end)
      
      case result do
        {:ok, stats} -> 
          IO.puts "Successfully generated access grants:"
          IO.puts "  Total grants: #{stats.total_grants}"
          IO.puts "  Users: #{stats.users}"
          IO.puts "  Average grants per user: #{stats.total_grants / stats.users}"
          {:ok, stats}
        {:error, error} -> 
          IO.puts "Error generating access grants: #{inspect error}"
          {:error, error}
      end
    end
  end
  
  # Private helper functions
  
  defp create_root_nodes(count, type) do
    for i <- 1..count do
      name = "Root #{i}"
      
      {:ok, node} = Hierarchy.create_node(%{
        name: name,
        node_type: type,
        metadata: %{"test_data" => true, "index" => i}
      })
      
      node.id
    end
  end
  
  defp create_child_nodes(0, _parent_ids, _types, _max_depth, stats), do: {:ok, stats}
  defp create_child_nodes(_count, [], _types, _max_depth, stats), do: {:ok, stats}
  defp create_child_nodes(_count, _parent_ids, _types, 0, stats), do: {:ok, stats}
  
  defp create_child_nodes(count, parent_ids, [_current_type | _remaining_types] = types, depth, stats) do
    # For each parent, create some children
    parent_count = length(parent_ids)
    children_per_parent = div(min(count, parent_count * 5), parent_count)
    
    # Create children for each parent
    {child_ids, new_stats} = 
      Enum.reduce(parent_ids, {[], stats}, fn parent_id, {ids_acc, stats_acc} ->
        parent_node = Hierarchy.get_node(parent_id)
        parent_depth = get_node_depth(parent_node.path)
        child_type = Enum.at(types, min(parent_depth + 1, length(types) - 1))
        
        # Create children for this parent
        new_child_ids = create_children_for_parent(parent_id, child_type, children_per_parent)
        
        # Update stats
        stats_acc = update_stats(stats_acc, new_child_ids, parent_depth + 1, child_type)
        
        {ids_acc ++ new_child_ids, stats_acc}
      end)
    
    # Continue with remaining nodes (depth-first traversal)
    remaining = count - (children_per_parent * parent_count)
    create_child_nodes(remaining, child_ids, types, depth - 1, new_stats)
  end
  
  defp create_children_for_parent(parent_id, type, count) do
    for i <- 1..count do
      name = "Node #{parent_id}_#{i}"
      
      {:ok, node} = Hierarchy.create_node(%{
        name: name,
        node_type: type,
        parent_id: parent_id,
        metadata: %{"test_data" => true, "parent" => parent_id, "index" => i}
      })
      
      node.id
    end
  end
  
  defp get_node_depth(path) when is_binary(path) do
    String.split(path, ".") |> length |> Kernel.-(1)
  end
  
  defp update_stats(stats, new_ids, depth, type) do
    count = length(new_ids)
    
    # Update total
    stats = Map.put(stats, :total_nodes, stats.total_nodes + count)
    
    # Update by level
    by_level = Map.update(stats.by_level, depth, count, &(&1 + count))
    stats = Map.put(stats, :by_level, by_level)
    
    # Update by type
    by_type = Map.update(stats.by_type, type, count, &(&1 + count))
    stats = Map.put(stats, :by_type, by_type)
    
    stats
  end
  
  defp get_or_create_test_users(count) do
    # Get existing test users
    existing_users = Repo.all(from u in User, 
      where: like(u.email, "test_user%@example.com"), 
      limit: ^count)
    
    # Calculate how many more we need
    to_create = count - length(existing_users)
    
    # Create additional users if needed
    created_users = 
      if to_create > 0 do
        for i <- 1..to_create do
          email = "test_user#{length(existing_users) + i}@example.com"
          password = "Password123!"
          
          # Use Pow context for user creation
          {:ok, user} = Pow.Ecto.Context.create(%{
            email: email,
            password: password,
            password_confirmation: password
          }, otp_app: :xiam)
          
          user
        end
      else
        []
      end
    
    existing_users ++ created_users
  end
end
