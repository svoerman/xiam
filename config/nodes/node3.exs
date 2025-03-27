import Config

# Override the port for this specific node
config :xiam, XIAMWeb.Endpoint,
  http: [
    ip: {127, 0, 0, 1},
    port: 4003
  ],
  server: true,
  secret_key_base: "IEg6/DIXMuMxodxryp/i564LCc8xkkKwkOkL2qrApz8TlJfFwHOdnDtZaJ/Bi1Ce",
  live_view: [signing_salt: "IEg6/DIXMuMxodxryp/i564LCc8xkkKwkOkL2qrApz8TlJfFwHOdnDtZaJ/Bi1Ce"]

# Set the cookie for distributed Erlang
config :xiam,
  cookie: "w0oIuVNI8XFFo/g4adGhIEKcck/FPegcxYWhFbVyL0eeyhzBYx/U9jo1I3woClj/"

# Override the database configuration
config :xiam, XIAM.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "xiam_test1",
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

# Enable clustering
config :xiam, :cluster_enabled, true
