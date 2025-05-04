defmodule XIAM.Cache.HierarchyCache do
  @moduledoc """
  Provides caching for hierarchy data to improve performance with large hierarchies.
  Uses ETS (Erlang Term Storage) for fast in-memory caching.
  """
  use GenServer
  require Logger
  
  @table_name :hierarchy_cache
  @default_ttl 5 * 60 * 1000 # 5 minutes in milliseconds
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Retrieve the cached value for a key, or compute and cache it if not found.
  """
  def get_or_store(key, compute_fun, ttl \\ @default_ttl) do
    case lookup(key) do
      {:ok, value} -> 
        # Cache hit - return the value
        value
        
      {:error, :not_found} ->
        # Cache miss - compute, store, and return value
        value = compute_fun.()
        store(key, value, ttl)
        value
    end
  end
  
  @doc """
  Manually store a value in the cache with a TTL.
  """
  def store(key, value, ttl \\ @default_ttl) do
    expires_at = System.monotonic_time(:millisecond) + ttl
    true = :ets.insert(@table_name, {key, value, expires_at})
    value
  end
  
  @doc """
  Lookup a value in the cache.
  Returns {:ok, value} if found and not expired, or {:error, :not_found}
  """
  def lookup(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, value, expires_at}] ->
        current_time = System.monotonic_time(:millisecond)
        if current_time < expires_at do
          {:ok, value}
        else
          # Expired entry - remove it
          :ets.delete(@table_name, key)
          {:error, :not_found}
        end
        
      [] -> 
        {:error, :not_found}
    end
  end
  
  @doc """
  Invalidate a specific cache entry.
  """
  def invalidate(key) do
    :ets.delete(@table_name, key)
    :ok
  end
  
  @doc """
  Invalidate all cache entries.
  """
  def invalidate_all do
    :ets.delete_all_objects(@table_name)
    :ok
  end
  
  @doc """
  Invalidate all cache entries that match a pattern.
  """
  def invalidate_pattern(pattern) when is_binary(pattern) do
    # Match and delete entries where the key contains the pattern
    # This is useful for invalidating hierarchical data by path prefix
    :ets.match_delete(@table_name, {{:_, pattern, :_}, :_, :_})
    :ok
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("Starting hierarchy cache...")
    # Create the ETS table as public so any process can read from it
    table = :ets.new(@table_name, [:set, :public, :named_table, 
                                  {:read_concurrency, true},
                                  {:write_concurrency, true}])
    
    # Start periodic cleanup of expired entries
    schedule_cleanup()
    
    {:ok, %{table: table}}
  end
  
  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired_entries()
    schedule_cleanup()
    {:noreply, state}
  end
  
  # Private functions
  
  defp cleanup_expired_entries do
    current_time = System.monotonic_time(:millisecond)
    
    # Find all expired entries
    expired_keys = :ets.foldl(fn {key, _value, expires_at}, acc ->
      if current_time >= expires_at do
        [key | acc]
      else
        acc
      end
    end, [], @table_name)
    
    # Delete expired entries
    Enum.each(expired_keys, &:ets.delete(@table_name, &1))
    
    if length(expired_keys) > 0 do
      Logger.debug("Cleaned up #{length(expired_keys)} expired cache entries")
    end
  end
  
  defp schedule_cleanup do
    # Run cleanup every minute
    Process.send_after(self(), :cleanup, 60_000)
  end
end
