#!/bin/bash

# Create config directory if it doesn't exist
mkdir -p config/nodes

# Generate a proper secret key base
SECRET_KEY_BASE=$(mix phx.gen.secret)

# Use the cookie from the environment
if [ -z "$CLUSTER_COOKIE" ]; then
    echo "Error: CLUSTER_COOKIE environment variable is not set"
    exit 1
fi

# Generate config for each node
for i in {1..3}; do
    port=$((4000 + i))
    cat > "config/nodes/node${i}.exs" << EOF
import Config

# Override the port for this specific node
config :xiam, XIAMWeb.Endpoint,
  http: [
    ip: {127, 0, 0, 1},
    port: ${port}
  ],
  server: true,
  secret_key_base: "${SECRET_KEY_BASE}",
  live_view: [signing_salt: "${SECRET_KEY_BASE}"]

# Set the cookie for distributed Erlang
config :xiam,
  cookie: "${CLUSTER_COOKIE}"

# Override the database configuration
config :xiam, XIAM.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "xiam_test${i}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  pool_timeout: 60000,
  ownership_timeout: :infinity,
  timeout: 60000,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

# Set the environment for this node
config :xiam, :env, :test

# Configure Oban for this node
config :xiam, Oban,
  repo: XIAM.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    {Oban.Plugins.Cron, crontab: []}
  ]

# Configure clustering
config :libcluster,
  debug: true,
  topologies: [
    xiam: [
      strategy: Cluster.Strategy.Epmd,
      config: [
        hosts: [
          :"node1@127.0.0.1",
          :"node2@127.0.0.1",
          :"node3@127.0.0.1"
        ],
        connect: true,
        polling_interval: 1000,
        timeout: 5000
      ]
    ]
  ]

# Disable sandbox mode for migrations
config :xiam, :sandbox, false

# Override the endpoint server setting
config :xiam, XIAMWeb.Endpoint, server: true

# Override the test partition to ensure we use the correct database
config :xiam, :mix_test_partition, "${i}"

# Enable clustering
config :xiam, :cluster_enabled, true
EOF
done

echo "Generated config files for nodes 1-3" 