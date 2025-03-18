import Config

config :xiam, XIAMWeb.Endpoint,
  url: [
    host: System.get_env("PHX_HOST", "localhost"),
    port: String.to_integer(System.get_env("PORT", "4000"))
  ],
  http: [
    port: String.to_integer(System.get_env("PORT", "4000")),
    transport_options: [socket_opts: [:inet6]]
  ],
  secret_key_base: System.get_env("SECRET_KEY_BASE"),
  server: true,
  cache_static_manifest: "priv/static/cache_manifest.json"

# Configure your database
config :xiam, XIAM.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE", "10")),
  ssl: true

# Configure email delivery
config :xiam, XIAM.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: System.get_env("SMTP_SERVER"),
  port: String.to_integer(System.get_env("SMTP_PORT", "587")),
  username: System.get_env("SMTP_USERNAME"),
  password: System.get_env("SMTP_PASSWORD"),
  ssl: false,
  tls: :always,
  auth: :always,
  retries: 3,
  no_mx_lookups: false

# Configure Oban for background jobs
config :xiam, Oban,
  repo: XIAM.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7}, # Keep jobs for 7 days
    {Oban.Plugins.Cron,
      crontab: [
        {"0 2 * * *", XIAM.Workers.DataRetentionWorker}, # Run GDPR cleanup at 2 AM
        {"*/5 * * * *", XIAM.Workers.HealthCheckWorker} # Run health checks every 5 minutes
      ]
    }
  ],
  queues: [default: 10, mailers: 20, gdpr: 5, background: 5]

# Configure JWT for API authentication
config :xiam, XIAM.Auth.JWT,
  secret_key: System.get_env("JWT_SECRET"),
  token_ttl: 60 * 60 * 24, # 24 hours
  refresh_ttl: 60 * 60 * 24 * 30 # 30 days

# Configure Pow authentication
config :xiam, :pow,
  user: XIAM.Users.User,
  repo: XIAM.Repo,
  web_module: XIAMWeb,
  cache_store_backend: Pow.Store.Backend.EtsCache,
  password_hash_methods: {Pow.Password.Pbkdf2, iterations: 100_000, format: :modular},
  password_min_length: 12

# PowAssent OAuth provider configuration
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

# Configure logger
config :logger, level: :info

# Import environment specific config
if File.exists?("config/#{config_env()}.runtime.exs") do
  import_config "#{config_env()}.runtime.exs"
end
