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
    # Instead of directly creating the Phoenix endpoint tables, we'll check
    # if they exist first and avoid creating them if they do.
    # This prevents conflicts when Phoenix itself tries to create them.
    endpoint = XIAMWeb.Endpoint
    
    # Only attempt to create non-Phoenix tables that should exist before application startup
    tables_to_ensure = [
      XIAM.Cache.HierarchyCache,
      XIAM.Hierarchy.AccessCache
    ]
    
    # Ensure application-specific tables exist
    Enum.each(tables_to_ensure, fn table -> 
      safely_ensure_table_exists(table)
    end)
    
    # For Phoenix tables, only check if they exist and initialize config if needed
    phoenix_tables = [endpoint, Phoenix.Config, Phoenix.LiveReloader]
    
    # For Phoenix tables, don't try to create them, just check if they need config
    phoenix_tables_status = Enum.map(phoenix_tables, fn table ->
      check_phoenix_table(table)
    end)
    
    # Only initialize endpoint config if tables already exist but might not be fully configured
    case phoenix_tables_status do
      [:exists, :exists, :exists] -> 
        # Tables exist, make sure they have the right configuration
        safely_initialize_phoenix_config()
      _ ->
        # Some tables don't exist yet, application startup will handle them
        :ok
    end
    
    :ok
  end
  
  # Check if a Phoenix table exists but don't try to create it
  defp check_phoenix_table(table_name) do
    try do
      case :ets.info(table_name) do
        :undefined -> :not_exists
        _ -> :exists
      end
    rescue
      _ -> :not_exists
    end
  end

  @doc """
  Initialize the Phoenix endpoint configuration ETS tables.
  This function is called from ConnCase setup to ensure Phoenix endpoint tables are properly configured.
  """
  def initialize_endpoint_config do
    # Make sure required ETS tables exist
    ensure_ets_tables_exist()
    
    # Set crucial Phoenix configuration for tests
    _endpoint = XIAMWeb.Endpoint
    app_module = :xiam
    app_dir = Application.app_dir(app_module)
    
    # Initialize endpoint configuration
    Application.put_env(:phoenix, :json_library, Jason)
    Application.put_env(app_module, :app_name, app_module)
    Application.put_env(app_module, :env, :test)
    Application.put_env(app_module, :app_dir, app_dir)
    
    # Return success
    :ok
  end
  
  @doc """
  Safely ensures an ETS table exists with proper error handling.
  This is a more resilient version that recovers from common errors.
  """
  def safely_ensure_table_exists(table_name) when is_atom(table_name) do
    # Check if the table already exists using a more resilient pattern
    # that works better with concurrent test processes
    try do
      case :ets.info(table_name) do
        :undefined ->
          # Table doesn't exist, try to create it with default options
          # We use try inside try to handle nested errors in a controlled way
          try do
            :ets.new(table_name, [:named_table, :public, read_concurrency: true])
            # Always return :ok for successful creation to ensure consistent return values
            # This avoids pattern matching issues in tests
            :ok
          rescue
            # The table might have been created by another process between our check and creation attempt
            ArgumentError -> 
              case :ets.info(table_name) do
                :undefined -> :error # Still undefined? That's unexpected
                _ -> :ok # Table exists now, so that's what we wanted
              end
          end
        _ ->
          # Table already exists, nothing to do
          :ok
      end
    rescue
      # The most resilient approach - if anything goes wrong, don't crash the test
      e -> 
        # Log the error and return error tuple
        IO.puts("Warning: Failed to ensure ETS table #{inspect(table_name)} exists: #{inspect(e)}")
        {:error, e}
    end
  end
  
  # For any non-atom table names (like tuples), we can't create them as ETS tables
  def safely_ensure_table_exists(table_name) do
    IO.puts("Warning: Cannot create ETS table for non-atom name: #{inspect(table_name)}")
    :undefined
  end
  
  @doc """
  Initializes basic endpoint configuration in the endpoint ETS table for tests,
  but only if the tables already exist. This avoids conflicts with Phoenix trying
  to create the tables itself.
  """
  def safely_initialize_phoenix_config do
    # Make sure the endpoint module is loaded
    endpoint = XIAMWeb.Endpoint
    
    # Critical application environment settings for LiveView tests
    # This addresses the "unknown application: nil" error in LiveView tests
    Application.put_env(:phoenix_live_view, :app_name, :xiam)
    Application.put_env(:phoenix, :json_library, Jason)
    Application.put_env(:xiam, :env, :test)
    
    # Check if the Phoenix tables actually exist before trying to modify them
    endpoint_exists = table_exists?(endpoint)
    config_exists = table_exists?(Phoenix.Config)
    
    if endpoint_exists and config_exists do
      # Get the actual runtime config
      config = Application.get_all_env(:xiam_web)[:endpoint] || %{}
      
      # Basic config required for many Phoenix operations
      basic_config = %{
        secret_key_base: config[:secret_key_base] || String.duplicate("a", 64),
        signing_salt: config[:signing_salt] || "test-signing-salt",
        live_view: [signing_salt: "test-lv-salt", application: :xiam],
        url: config[:url] || [host: "localhost", port: 4000],
        render_errors: config[:render_errors] || [view: XIAMWeb.ErrorHTML, accepts: ~w(html json)]
      }
      
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
    end
    
    :ok
  end
  
  # Private helper to safely check if a table exists
  defp table_exists?(table_name) do
    try do
      case :ets.info(table_name) do
        :undefined -> false
        _ -> true
      end
    rescue
      _ -> false
    end
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
