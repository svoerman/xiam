# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :xiam,
  namespace: XIAM,
  ecto_repos: [XIAM.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :xiam, XIAMWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  http: [
    ip: {127, 0, 0, 1}
  ],
  render_errors: [
    formats: [html: XIAMWeb.ErrorHTML, json: XIAMWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: XIAM.PubSub,
  live_view: [signing_salt: "B05JLS67"],
  secret_key_base: "your-secret-key-base-here",
  session: [
    key: "_xiam_session",
    max_age: 60 * 60 * 24 * 7, # 7 days
    same_site: "Lax",
    secure: false,
    http_only: true
  ],
  plug_session: [
    key: "_xiam_session",
    max_age: 60 * 60 * 24 * 7, # 7 days
    same_site: "Lax",
    secure: false,
    http_only: true
  ]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :xiam, XIAM.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  xiam: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  xiam: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason



config :xiam, :pow,
  user: XIAM.Users.User,
  repo: XIAM.Repo,
  web_module: XIAMWeb,
  controller_callbacks: XIAMWeb.Pow.ControllerCallbacks,
  controllers: [
    session: XIAMWeb.Pow.SessionController
  ]

# Configure Oban for background jobs
config :xiam, Oban,
  repo: XIAM.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10, audit: 20, emails: 10]

# Configure LibCluster for node clustering
cluster_topologies =
  case System.get_env("CLUSTER_ENABLED", "true") do
    "true" -> [
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
    _ -> []
  end

config :libcluster,
  debug: true,
  topologies: cluster_topologies

# Configure PowAssent providers
config :xiam, :pow_assent,
  providers: [
    github: [
      client_id: System.get_env("GITHUB_CLIENT_ID"),
      client_secret: System.get_env("GITHUB_CLIENT_SECRET"),
      strategy: Assent.Strategy.Github
    ],
    google: [
      client_id: System.get_env("GOOGLE_CLIENT_ID"),
      client_secret: System.get_env("GOOGLE_CLIENT_SECRET"),
      strategy: Assent.Strategy.Google
    ]
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
