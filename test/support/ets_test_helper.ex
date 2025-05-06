defmodule XIAM.ETSTestHelper do
  @moduledoc """
  Helper functions for dealing with ETS tables in tests.
  
  Phoenix uses ETS tables for endpoint configuration, session storage, and other features.
  In test environments, these tables might not be properly initialized before tests run,
  causing errors when attempting lookups.
  
  This module provides functions to ensure those tables exist and are properly initialized.
  
  Implementation note: Many Phoenix component tests fail because Phoenix creates ETS tables
  during application startup, which can cause conflicts in the test environment. We use a
  defensive approach that avoids these conflicts while still providing the necessary tables.
  """
  
  @doc """
  Ensures that all required ETS tables for testing with Phoenix endpoints are created.
  Call this in your test setup to avoid ETS table lookup errors.
  """
  def ensure_ets_tables_exist do
    # Make sure the Phoenix endpoint is loaded
    endpoint = XIAMWeb.Endpoint
    
    # Create a list of all Phoenix-related ETS tables we need to ensure exist
    # This includes the endpoint itself, Phoenix.Config, and Phoenix.LiveReloader
    tables_to_ensure = [
      endpoint,
      Phoenix.Config,
      Phoenix.LiveReloader,
      XIAM.Cache.HierarchyCache,
      XIAM.Hierarchy.AccessCache
    ]
    
    # Ensure each table exists
    Enum.each(tables_to_ensure, fn table -> 
      safely_ensure_table_exists(table)
    end)
    
    # Initialize the endpoint configuration
    initialize_endpoint_config()
    
    :ok
  end
  
  @doc """
  Safely ensures an ETS table exists with proper error handling.
  This is a more resilient version that recovers from common errors.
  """
  def safely_ensure_table_exists(table_name) when is_atom(table_name) do
    try do
      case :ets.info(table_name) do
        :undefined ->
          # Table doesn't exist, try to create it
          try do
            :ets.new(table_name, [:named_table, :public, :set, {:read_concurrency, true}])
          rescue
            ArgumentError -> 
              # Table already exists (race condition) or other creation error
              IO.puts("Warning: Could not create ETS table #{inspect(table_name)}, may already exist")
          end
        _ ->
          # Table exists, do nothing
          :ok
      end
    rescue
      _ -> 
        # Error checking table existence, try to create it
        try do
          :ets.new(table_name, [:named_table, :public, :set, {:read_concurrency, true}])
        rescue
          _ -> 
            # Failed to create, but we'll continue anyway
            IO.puts("Warning: Failed to ensure ETS table #{inspect(table_name)} exists")
        end
    end
  end
  
  # For any non-atom table names (like tuples), we can't create them as ETS tables
  def safely_ensure_table_exists(table_name) do
    IO.puts("Warning: Cannot create ETS table for non-atom name: #{inspect(table_name)}")
    :undefined
  end
  
  @doc """
  Initializes basic endpoint configuration in the endpoint ETS table for tests.
  In Phoenix, the endpoint configuration is stored in an ETS table named after the endpoint module.
  """
  def initialize_endpoint_config do
    # Make sure the endpoint module is loaded
    endpoint = XIAMWeb.Endpoint
    
    # Get the actual runtime config
    config = Application.get_all_env(:xiam_web)[:endpoint] || %{}
    
    # Basic config required for many Phoenix operations
    basic_config = %{
      secret_key_base: config[:secret_key_base] || String.duplicate("a", 64),
      signing_salt: config[:signing_salt] || "test-signing-salt",
      live_view: config[:live_view] || [signing_salt: "test-lv-salt"],
      url: config[:url] || [host: "localhost", port: 4000],
      render_errors: config[:render_errors] || [view: XIAMWeb.ErrorHTML, accepts: ~w(html json)]
    }
    
    # In Phoenix, the endpoint configuration is stored in a single ETS table
    # that's named after the endpoint module
    safely_ensure_table_exists(endpoint)
    safely_ensure_table_exists(Phoenix.Config)
    
    # Store all config items in the endpoint table
    # Use try/rescue to handle potential ETS errors gracefully
    try do
      for {key, value} <- basic_config do
        :ets.insert(endpoint, {key, value})
      end
    rescue
      _ -> 
        IO.puts("Warning: Could not insert configuration into endpoint ETS table")
    end
    
    # Configure Phoenix.Config ETS table
    # Phoenix looks up dynamic configurations through this table
    try do
      # Store endpoint configuration in Phoenix.Config table
      # This is used by the Phoenix framework for dynamic config
      :ets.insert(Phoenix.Config, {endpoint, basic_config})
    rescue
      _ -> 
        IO.puts("Warning: Could not insert configuration into Phoenix.Config ETS table")
    end
    
    # Phoenix also looks up values using Application env during tests
    # Store configuration in Application env with proper keys
    Application.put_env(:xiam_web, endpoint, basic_config)
    Application.put_env(:phoenix, :endpoint, basic_config)
    
    # Phoenix can also look up individual keys under the :phoenix namespace
    for {key, value} <- basic_config do
      Application.put_env(:phoenix, key, value)
    end
    
    :ok
  end
  
  @doc """
  Cleanly restart Phoenix endpoint to ensure all tables are properly initialized.
  This is a more aggressive approach to fixing ETS tables issues but can be useful
  for tests that are particularly sensitive to ETS table problems.
  """
  def restart_endpoint do
    # Get a reference to the endpoint
    endpoint = XIAMWeb.Endpoint

    # Phoenix.Endpoint doesn't expose a direct stop/0 function in newer versions
    # Instead we'll use Process.whereis to find the endpoint process
    try do
      endpoint_pid = Process.whereis(endpoint)
      if endpoint_pid && Process.alive?(endpoint_pid) do
        # Use Supervisor.stop/2 to stop the endpoint supervisor
        Supervisor.stop(endpoint_pid)
      end
    rescue
      _ -> :ok
    end

    # Ensure all ETS tables exist
    ensure_ets_tables_exist()

    # Start the endpoint again
    try do
      {:ok, _} = endpoint.start_link()
      :ok
    rescue
      e -> 
        IO.puts("Warning: Could not restart endpoint - #{inspect(e)}")
        :error
    end
  end
end
