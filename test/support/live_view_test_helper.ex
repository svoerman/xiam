defmodule XIAM.LiveViewTestHelper do
  @moduledoc """
  Helper module for LiveView tests that provides consistent setup and initialization.
  
  This module ensures that all necessary environment variables and ETS tables
  are properly configured for LiveView tests to work correctly.
  """
  
  @doc """
  Initialize the test environment for Phoenix LiveView tests.
  Should be called in the setup block of LiveView test modules.
  """
  def initialize_live_view_test_env do
    # First, ensure critical application environment variables are set
    # This must be done before any Phoenix code tries to access these values
    Application.put_env(:phoenix_live_view, :app_name, :xiam)
    Application.put_env(:phoenix, :json_library, Jason)
    Application.put_env(:xiam, :env, :test)
    Application.put_env(:phoenix_live_view, :app_dir, Application.app_dir(:phoenix))
    
    # Initialize application-specific ETS tables with less strict pattern matching
    XIAM.ETSTestHelper.safely_ensure_table_exists(:hierarchy_cache)
    XIAM.ETSTestHelper.safely_ensure_table_exists(:hierarchy_cache_metrics)
    XIAM.ETSTestHelper.safely_ensure_table_exists(:access_cache)
    
    # If endpoint is not started, ensure it's properly initialized
    unless Process.whereis(XIAMWeb.Endpoint) do
      # Configure endpoint before starting
      XIAM.ETSTestHelper.safely_initialize_phoenix_config()
    end
    
    # Return success indicator
    :ok
  end
end
