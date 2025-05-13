defmodule XIAM.ETSTestHelper do
  @moduledoc """
  Helper module for managing ETS tables in tests.
  
  This module provides functions to ensure ETS tables exist and are properly initialized
  before tests that depend on them are run.
  """
  
  @doc """
  Ensures that all required ETS tables exist.
  If a table doesn't exist, it creates it with proper options.
  """
  def ensure_ets_tables_exist do
    ensure_table_exists(:user_token)
    ensure_table_exists(:phoenix_endpoint)
    ensure_table_exists(:cache)
    ensure_table_exists(:hierarchy_cache)
    ensure_table_exists(:hierarchy_cache_metrics)
    ensure_table_exists(:access_cache)
    :ok
  end
  
  @doc """
  Ensures that a specific ETS table exists.
  If the table doesn't exist, it creates it with public, named_table, and set options.
  """
  def ensure_table_exists(table_name) when is_atom(table_name) do
    if :ets.whereis(table_name) == :undefined do
      :ets.new(table_name, [:named_table, :public, :set])
      true
    else
      false
    end
  end
  
  @doc """
  Safely ensures a table exists, handling any errors that might occur.
  """
  def safely_ensure_table_exists(table_name) do
    try do
      ensure_table_exists(table_name)
    rescue
      e -> 
        IO.puts("[WARNING] Error creating ETS table #{table_name}: #{inspect(e)}")
        false
    catch
      kind, value ->
        IO.puts("[WARNING] Error creating ETS table #{table_name} (#{kind}): #{inspect(value)}")
        false
    end
  end
  
  @doc """
  Initializes Phoenix endpoint configuration in ETS.
  """
  def initialize_endpoint_config do
    # Get the endpoint module from XIAMWeb if available
    endpoint = 
      if Code.ensure_loaded?(XIAMWeb) && Code.ensure_loaded?(XIAMWeb.Endpoint) do
        XIAMWeb.Endpoint
      else
        nil
      end
      
    # If we have an endpoint, ensure its configuration is initialized
    if endpoint != nil do
      ensure_table_exists(:phoenix_endpoint)
      ensure_table_exists(:user_token)
      :ok
    else
      :ok
    end
  end
  
  @doc """
  Safely initializes Phoenix configuration, handling any errors.
  """
  def safely_initialize_phoenix_config do
    try do
      initialize_endpoint_config()
      :ok
    rescue
      e -> 
        IO.puts("[WARNING] Error initializing Phoenix config: #{inspect(e)}")
        :error
    end
  end
end
