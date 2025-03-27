import Config

# This file is only used for cluster testing
# It should be imported by your test configs

# Configure your database
config :xiam, XIAM.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "xiam_test#{config_env()}",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For cluster testing, we'll use a different port for each node
config :xiam, XIAMWeb.Endpoint,
  http: [
    ip: {127, 0, 0, 1},
    port: String.to_integer(System.get_env("PHX_PORT", "4000"))
  ],
  secret_key_base: "your-secret-key-base-here",
  server: true

# Configure the cluster
config :libcluster,
  topologies: [
    example: [
      strategy: Cluster.Strategy.Gossip
    ]
  ]

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
