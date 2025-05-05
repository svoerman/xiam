defmodule XIAM.Hierarchy.AccessCache do
  @moduledoc """
  Cache layer for hierarchy access checks to improve performance.
  
  This module provides caching for frequently used access checks to reduce database load.
  It automatically expires cache entries after a configurable TTL and has protection
  against cache poisoning with a maximum cache size.
  
  Used by the AccessManager for efficient access checks.
  """
  use GenServer
  require Logger
  
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
  Gets a value from the cache or stores it if not present.
  Similar to XIAM.Cache.HierarchyCache.get_or_store/3 but specialized for access checks.
  """
  def get_or_store(key, fun, ttl \\ @default_ttl) do
    # Try to use the cache server, but gracefully handle the case where it's not available (e.g. in tests)
    try do
      case GenServer.call(__MODULE__, {:check, key}) do
        {:miss} ->
          # Not in cache, call the function
          value = fun.()
          GenServer.cast(__MODULE__, {:store, key, value, ttl})
          value
        {:hit, value} ->
          # Cache hit
          value
      end
    catch
      # Gracefully handle the case where the GenServer is not running (e.g. during tests)
      :exit, _ ->
        if Process.alive?(self()) do 
          Logger.debug("AccessCache not available, falling back to direct function call")
          # Just call the function directly without caching
          fun.()
        else
          # Re-raise if we're not actually alive
          exit(:normal)
        end
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
  def handle_call({:check, key}, _from, state) do
    case Map.get(state.cache, key) do
      nil ->
        # Cache miss
        {:reply, {:miss}, state}
      {value, timestamp, ttl} ->
        # Check if entry is still valid
        if :os.system_time(:millisecond) - timestamp < ttl do
          # Valid cache hit
          {:reply, {:hit, value}, state}
        else
          # Expired entry
          {:reply, {:miss}, %{state | cache: Map.delete(state.cache, key)}}
        end
    end
  end
  
  @impl true
  def handle_cast({:store, key, value, ttl}, state) do
    timestamp = :os.system_time(:millisecond)
    
    # If at max size, remove oldest entries before adding new one
    cache = 
      if map_size(state.cache) >= state.max_size do
        # Sort by timestamp and keep the newest entries
        cache_list = 
          state.cache
          |> Enum.sort_by(fn {_k, {_v, ts, _ttl}} -> ts end, :desc)
          |> Enum.take(state.max_size - 1)
          |> Map.new()
          
        # Add new entry
        Map.put(cache_list, key, {value, timestamp, ttl})
      else
        # Simply add new entry
        Map.put(state.cache, key, {value, timestamp, ttl})
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
      |> Enum.reject(fn {_, {_, timestamp, ttl}} -> 
        current_time - timestamp >= ttl
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
