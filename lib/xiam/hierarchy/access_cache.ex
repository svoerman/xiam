defmodule XIAM.Hierarchy.AccessCache do
  @moduledoc """
  Cache layer for hierarchy access checks to improve performance.
  
  This module provides caching for frequently used access checks to reduce database load.
  It automatically expires cache entries after a configurable TTL and has protection
  against cache poisoning with a maximum cache size.
  """
  use GenServer
  require Logger
  
  alias XIAM.Hierarchy
  
  # Default TTL for cache entries (5 minutes)
  @default_ttl 300_000
  
  # Default maximum cache size to prevent memory issues
  @default_max_size 10_000
  
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    ttl = Keyword.get(opts, :ttl, @default_ttl)
    max_size = Keyword.get(opts, :max_size, @default_max_size)
    
    GenServer.start_link(__MODULE__, %{ttl: ttl, max_size: max_size, cache: %{}}, name: name)
  end
  
  @doc """
  Checks if a user has access to a node, using the cache if available.
  """
  def can_access?(user_id, node_id) do
    case GenServer.call(__MODULE__, {:check_cache, user_id, node_id}) do
      {:miss} ->
        # Not in cache, check database
        has_access = Hierarchy.can_access?(user_id, node_id)
        GenServer.cast(__MODULE__, {:cache, user_id, node_id, has_access})
        has_access
      {:hit, has_access} ->
        # Cache hit
        has_access
    end
  end
  
  @doc """
  Invalidates cache entries related to a specific user.
  Use this when user permissions change.
  """
  def invalidate_user(user_id) do
    GenServer.cast(__MODULE__, {:invalidate_user, user_id})
  end
  
  @doc """
  Invalidates cache entries related to a specific node.
  Use this when node permissions or hierarchy structure changes.
  """
  def invalidate_node(node_id) do
    GenServer.cast(__MODULE__, {:invalidate_node, node_id})
  end
  
  @doc """
  Completely clears the cache.
  """
  def clear_cache do
    GenServer.cast(__MODULE__, :clear_cache)
  end
  
  # GenServer callbacks
  
  @impl true
  def init(state) do
    # Schedule periodic cleanup
    schedule_cleanup(state.ttl)
    {:ok, state}
  end
  
  @impl true
  def handle_call({:check_cache, user_id, node_id}, _from, state) do
    key = {user_id, node_id}
    
    case Map.get(state.cache, key) do
      nil ->
        # Cache miss
        {:reply, {:miss}, state}
      {has_access, timestamp} ->
        # Check if entry is still valid
        if :os.system_time(:millisecond) - timestamp < state.ttl do
          # Valid cache hit
          {:reply, {:hit, has_access}, state}
        else
          # Expired entry
          {:reply, {:miss}, %{state | cache: Map.delete(state.cache, key)}}
        end
    end
  end
  
  @impl true
  def handle_cast({:cache, user_id, node_id, has_access}, state) do
    key = {user_id, node_id}
    timestamp = :os.system_time(:millisecond)
    
    # If at max size, remove oldest entries before adding new one
    cache = 
      if map_size(state.cache) >= state.max_size do
        # Sort by timestamp and keep the newest entries
        cache_list = 
          state.cache
          |> Enum.sort_by(fn {_k, {_v, ts}} -> ts end, :desc)
          |> Enum.take(state.max_size - 1)
          |> Map.new()
          
        # Add new entry
        Map.put(cache_list, key, {has_access, timestamp})
      else
        # Simply add new entry
        Map.put(state.cache, key, {has_access, timestamp})
      end
    
    {:noreply, %{state | cache: cache}}
  end
  
  @impl true
  def handle_cast({:invalidate_user, user_id}, state) do
    # Remove all entries for this user
    cache = 
      state.cache
      |> Enum.reject(fn {{uid, _}, _} -> uid == user_id end)
      |> Map.new()
    
    {:noreply, %{state | cache: cache}}
  end
  
  @impl true
  def handle_cast({:invalidate_node, node_id}, state) do
    # Remove all entries for this node
    cache = 
      state.cache
      |> Enum.reject(fn {{_, nid}, _} -> nid == node_id end)
      |> Map.new()
    
    {:noreply, %{state | cache: cache}}
  end
  
  @impl true
  def handle_cast(:clear_cache, state) do
    {:noreply, %{state | cache: %{}}}
  end
  
  @impl true
  def handle_info(:cleanup, state) do
    # Remove expired entries
    current_time = :os.system_time(:millisecond)
    
    cache = 
      state.cache
      |> Enum.reject(fn {_, {_, timestamp}} -> 
        current_time - timestamp >= state.ttl
      end)
      |> Map.new()
    
    # Schedule next cleanup
    schedule_cleanup(state.ttl)
    
    {:noreply, %{state | cache: cache}}
  end
  
  defp schedule_cleanup(ttl) do
    # Run cleanup at half the TTL interval
    cleanup_interval = max(div(ttl, 2), 10_000)
    Process.send_after(self(), :cleanup, cleanup_interval)
  end
end
