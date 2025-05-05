defmodule XIAM.Cache.HierarchyCache do
  @moduledoc """
  Provides caching for hierarchy data to improve performance with large hierarchies.
  Uses ETS (Erlang Term Storage) for fast in-memory caching.
  Includes monitoring capabilities to track cache hit rates and adjust TTLs.
  """
  use GenServer
  require Logger
  
  @table_name :hierarchy_cache
  @metrics_table_name :hierarchy_cache_metrics
  @default_ttl 5 * 60 * 1000 # 5 minutes in milliseconds
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Retrieve the cached value for a key, or compute and cache it if not found.
  Also tracks metrics for cache hit rate monitoring.
  """
  def get_or_store(key, compute_fun, ttl \\ @default_ttl) do
    prefix = get_key_prefix(key)
    
    case lookup(key) do
      {:ok, value} -> 
        # Cache hit - record metric and return the value
        increment_counter(:hits, prefix)
        increment_counter(:total_accesses, prefix)
        value
        
      {:error, :not_found} ->
        # Cache miss - compute, store, record metric, and return value
        increment_counter(:misses, prefix)
        increment_counter(:total_accesses, prefix)
        value = compute_fun.()
        store(key, value, ttl)
        value
    end
  end
  
  @doc """
  Manually store a value in the cache with a TTL.
  """
  def store(key, value, ttl \\ @default_ttl) do
    prefix = get_key_prefix(key)
    increment_counter(:stores, prefix)
    
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
    prefix = get_key_prefix(key)
    increment_counter(:invalidations, prefix)
    
    :ets.delete(@table_name, key)
    :ok
  end
  
  @doc """
  Invalidate all cache entries.
  """
  def invalidate_all do
    # Record a full invalidation event for monitoring
    increment_counter(:full_invalidations, "all")
    
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
  
  # Cache Monitoring API
  
  @doc """
  Get current cache metrics including hit rate, miss rate, and total accesses.
  """
  def get_metrics do
    # Get all metrics from the ETS table
    metrics = :ets.tab2list(@metrics_table_name)
    
    # Group metrics by prefix
    metrics_by_prefix = Enum.reduce(metrics, %{}, fn {{prefix, metric_type}, count}, acc -> 
      prefix_metrics = Map.get(acc, prefix, %{})
      updated_metrics = Map.put(prefix_metrics, metric_type, count)
      Map.put(acc, prefix, updated_metrics)
    end)
    
    # Calculate hit rates and additional metrics for each prefix
    Enum.map(metrics_by_prefix, fn {prefix, metrics} -> 
      hits = Map.get(metrics, :hits, 0)
      misses = Map.get(metrics, :misses, 0)
      total = hits + misses
      hit_rate = if total > 0, do: hits / total * 100, else: 0
      
      %{
        prefix: prefix,
        hits: hits,
        misses: misses,
        stores: Map.get(metrics, :stores, 0),
        invalidations: Map.get(metrics, :invalidations, 0),
        total_accesses: Map.get(metrics, :total_accesses, 0),
        hit_rate: hit_rate
      }
    end)
  end
  
  @doc """
  Get the overall hit rate for the cache.
  """
  def get_hit_rate do
    total_hits = get_counter_value(:hits, :all)
    total_misses = get_counter_value(:misses, :all)
    total = total_hits + total_misses
    
    if total > 0 do
      total_hits / total * 100
    else
      0
    end
  end
  
  @doc """
  Get counter values for a specific metric across all prefixes.
  Returns a map of prefix => value.
  """
  def get_counter_value(metric) do
    counters = :ets.match(@metrics_table_name, {{:'$1', metric}, :'$2'})
    
    # Convert the list of [prefix, value] matches to a map
    Enum.reduce(counters, %{}, fn [prefix, value], acc -> 
      Map.put(acc, prefix, value)
    end)
  end
  
  @doc """
  Reset all cache metrics.
  """
  def reset_metrics do
    :ets.delete_all_objects(@metrics_table_name)
    :ok
  end
  
  @doc """
  Suggest optimal TTL settings based on access patterns.
  Returns recommendations for TTL adjustments based on hit rates.
  """
  def suggest_ttl_adjustments do
    metrics = get_metrics()
    
    Enum.map(metrics, fn %{prefix: prefix, hit_rate: hit_rate} -> 
      cond do
        hit_rate < 50 -> %{prefix: prefix, current_hit_rate: hit_rate, suggestion: "Decrease TTL to reduce memory usage"}
        hit_rate > 95 -> %{prefix: prefix, current_hit_rate: hit_rate, suggestion: "Increase TTL for better performance"}
        true -> %{prefix: prefix, current_hit_rate: hit_rate, suggestion: "TTL seems optimal"}
      end
    end)
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("Starting hierarchy cache...")
    # Create the ETS table as public so any process can read from it
    table = :ets.new(@table_name, [:set, :public, :named_table, 
                                 {:read_concurrency, true},
                                 {:write_concurrency, true}])
    
    # Create metrics table
    metrics_table = :ets.new(@metrics_table_name, [:set, :public, :named_table, 
                                                {:write_concurrency, true}])
    
    # Start periodic cleanup of expired entries
    schedule_cleanup()
    
    # Schedule periodic metrics logging
    schedule_metrics_logging()
    
    {:ok, %{table: table, metrics_table: metrics_table}}
  end
  
  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired_entries()
    schedule_cleanup()
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:log_metrics, state) do
    log_cache_metrics()
    schedule_metrics_logging()
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
      # Track expirations for monitoring
      increment_counter(:expirations, "all", length(expired_keys))
    end
  end
  
  defp schedule_cleanup do
    # Run cleanup every minute
    Process.send_after(self(), :cleanup, 60_000)
  end
  
  defp schedule_metrics_logging do
    # Log metrics every 10 minutes
    Process.send_after(self(), :log_metrics, 10 * 60 * 1000)
  end
  
  defp log_cache_metrics do
    metrics = get_metrics()
    hit_rate = get_hit_rate()
    
    Logger.info("Hierarchy Cache Stats - Overall hit rate: #{Float.round(hit_rate * 1.0, 2)}%")
    
    # Log stats for key prefixes with significant activity
    active_metrics = Enum.filter(metrics, fn %{total_accesses: total} -> total > 100 end)
    
    Enum.each(active_metrics, fn %{prefix: prefix, hit_rate: rate, total_accesses: total} ->
      Logger.info("Cache prefix '#{prefix}' - Hit rate: #{Float.round(rate * 1.0, 2)}%, Accesses: #{total}")
    end)
    
    # Log TTL adjustment suggestions for low or high hit rates
    adjustment_suggestions = suggest_ttl_adjustments()
    
    needs_adjustment = Enum.filter(adjustment_suggestions, fn %{suggestion: suggestion} ->
      suggestion != "TTL seems optimal"
    end)
    
    if length(needs_adjustment) > 0 do
      Logger.info("Cache TTL adjustment suggestions:")
      Enum.each(needs_adjustment, fn %{prefix: prefix, current_hit_rate: rate, suggestion: suggestion} ->
        Logger.info("  #{prefix}: #{suggestion} (current hit rate: #{Float.round(rate * 1.0, 2)}%)")
      end)
    end
  end
  
  # Helpers for cache key categorization and metrics
  
  defp get_key_prefix(key) when is_binary(key) do
    cond do
      String.starts_with?(key, "node:") -> "node"
      String.starts_with?(key, "node_path:") -> "node_path"
      String.starts_with?(key, "children:") -> "children"
      String.starts_with?(key, "root_nodes") -> "root_nodes"
      String.starts_with?(key, "access_check:") -> "access_check"
      String.starts_with?(key, "accessible_nodes:") -> "accessible_nodes"
      true -> "other"
    end
  end
  
  defp get_key_prefix(_), do: "other"
  
  defp increment_counter(metric_type, prefix, increment \\ 1) do
    # Increment for specific prefix
    :ets.update_counter(@metrics_table_name, {prefix, metric_type}, {2, increment}, {{prefix, metric_type}, 0})
    
    # Also increment for overall stats
    :ets.update_counter(@metrics_table_name, {:all, metric_type}, {2, increment}, {{:all, metric_type}, 0})
  end
  
  defp get_counter_value(metric_type, prefix) do
    case :ets.lookup(@metrics_table_name, {prefix, metric_type}) do
      [{{^prefix, ^metric_type}, count}] -> count
      [] -> 0
    end
  end
end
