import Config

# Override the port for this specific node
config :xiam, XIAMWeb.Endpoint,
  http: [
    ip: {127, 0, 0, 1},
    port: 4002
  ],
  server: true,
  secret_key_base: "y/pgsbymAZ8IRPqlIouDG+wJCZz53bZCcu/JfPdw8rJydnUh7se/XJYJV/s1zpL4",
  live_view: [signing_salt: "y/pgsbymAZ8IRPqlIouDG+wJCZz53bZCcu/JfPdw8rJydnUh7se/XJYJV/s1zpL4"]

# Set the cookie for distributed Erlang
config :xiam,
  cookie: "XH1LVSXAI9Qtryg/PiTvCR3MjwXPDofqflhPYmaWrq4pAcuqy1k/lXGdihHlUJMs"

# Override the database configuration
config :xiam, XIAM.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "xiam_test2",
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
        polling_interval: 5_000,
        timeout: 30_000
      ]
    ]
  ]

# Disable sandbox mode for migrations
config :xiam, :sandbox, false

# Override the endpoint server setting
config :xiam, XIAMWeb.Endpoint, server: true

# Override the test partition to ensure we use the correct database
config :xiam, :mix_test_partition, "2"

# Enable clustering
config :xiam, :cluster_enabled, true
