import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :xiam, XIAM.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "xiam_test1",
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :xiam, XIAMWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "GnJlTwbNX1ocJyCWiSeUx6ang83155doHvQf/E3+wEWkFREqfKEtf40Uwxys1neN",
  server: false

# In test we don't send emails
config :xiam, XIAM.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Show info level logs during test to capture application startup messages
config :logger, level: :info

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Configure JWT settings for testing
config :xiam,
  jwt_signing_key: "t3st_s3cr3t_k3y_d1ff3r3nt_fr0m_d3v_and_pr0d",
  jwt_token_expiry: 3600 # Short expiry for tests (1 hour)

# Add coverage configuration
config :xiam, :test_coverage,
  ignore_modules: [
    XIAM.ObanTestHelper,
    ~r/.*_meck_original$/,
    ~r/.*Test$/
  ]

# Configure coverage tools
config :excoveralls,
  clear_cover: true,
  skip_files: [
    "test/support/",
    "_build/",
    "deps/"
  ]

# Configure Oban for testing - completely disable it to avoid ownership errors
config :oban,
  testing: :manual,
  plugins: false,
  queues: false,
  peer: false,
  repo: XIAM.Repo

# Flag to indicate test environment for the application
config :xiam, oban_testing: true
