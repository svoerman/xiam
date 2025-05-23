defmodule XIAM.Application do
  # Load compiler defaults to suppress warnings
  require XIAM.CompilerDefaults
  XIAM.CompilerDefaults.configure_compiler()

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
  # Suppress batch_create_nodes warning
  require XIAM.BatchWarningSuppressor
  XIAM.BatchWarningSuppressor.suppress_warnings()

    # Store application start time for uptime calculations
    Application.put_env(:xiam, :started_at, System.system_time(:second))

    # Initialize settings cache
    init_settings_cache()

    # Only start clustering if explicitly enabled and properly configured
    cluster_enabled = System.get_env("CLUSTER_ENABLED") == "true"
    topologies = if cluster_enabled, do: (Application.get_env(:libcluster, :topologies) || []), else: []

    # Base children that are always started
    children = [
      XIAMWeb.Telemetry,
      XIAM.Repo,
      {DNSCluster, query: Application.get_env(:xiam, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: XIAM.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: XIAM.Finch}
    ]
    
    # Don't start Oban in test environment or conditionally start it
    children = 
      case Application.get_env(:xiam, :oban_testing) do
        # Skip Oban in test mode
        true -> children
        # Include Oban in regular operation
        _ -> children ++ [{Oban, Application.get_env(:xiam, Oban)}]
      end
      
    # Add remaining services
    children = children ++ [
      # Start libcluster for node clustering
      {Cluster.Supervisor, [topologies, [name: XIAM.ClusterSupervisor]]},
      # Start the passkey token replay protection GenServer
      XIAM.Auth.PasskeyTokenReplay,
      # Start the hierarchy access cache for improved performance
      XIAM.Hierarchy.AccessCache,
      # Start the hierarchy data cache for large hierarchies
      XIAM.Cache.HierarchyCache,
      # Start to serve requests, typically the last entry
      XIAMWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: XIAM.Supervisor]
    result = Supervisor.start_link(children, opts)

    result # Return original result
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    XIAMWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # Initialize settings cache on application startup
  defp init_settings_cache do
    # Skip in test environment
    unless Mix.env() == :test do
      # Wait for database connection to be established
      Task.start(fn ->
        # Sleep briefly to ensure repo is started
        Process.sleep(1000)

        try do
          # Initialize the settings cache
          XIAM.System.Settings.init_cache()

          # Schedule initial health check
          XIAM.Workers.HealthCheckWorker.schedule()

          # Schedule initial data retention job
          XIAM.Workers.DataRetentionWorker.schedule()
        rescue
          e ->
            # Log any errors during initialization
            require Logger
            Logger.error("Error initializing settings: #{inspect(e)}")
        end
      end)
    end
  end
end
