# Oban test helper is loaded automatically - don't require it explicitly

# Set up logger configuration to suppress specific error messages during tests
# Suppress CBOR decoding errors by setting a higher log level during tests
require Logger
original_level = Logger.level()
Logger.configure(level: :critical)

# Restore the original log level when tests complete
System.at_exit(fn _status -> 
  Logger.configure(level: original_level)
end)

# Make sure the application is started before tests
Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto)
Application.ensure_all_started(:xiam)

# Compile the ResilientDatabaseSetup module to ensure it's available
Code.ensure_compiled(XIAM.ResilientDatabaseSetup)

# Disable Oban for testing (before ExUnit starts)
Application.put_env(:oban, :testing, :manual)
Application.put_env(:oban, :queues, false)
Application.put_env(:oban, :plugins, false)
Application.put_env(:oban, :peer, false)
Application.put_env(:xiam, :oban_testing, true)


# Mox setup for XIAM.Users
Mox.defmock(XIAM.Users.Mock, for: XIAM.Users.Behaviour)
Application.put_env(:xiam, :users, XIAM.Users.Mock)

# We'll simplify our testing approach for the refactored components
# and rely on the existing test infrastructure

# Configure ExUnit with improved test pattern recognition
ExUnit.configure(
  # Only exclude pending tags, include previously skipped tests
  exclude: [pending: true],
  include: [:test],
  patterns: ["*_test.exs", "test_*.exs", "*/*_test.exs"]
)
# Make sure Phoenix endpoint is started to initialize ETS tables
Application.ensure_all_started(:phoenix)
Application.ensure_all_started(:phoenix_ecto)

# Start ExUnit
ExUnit.start()

# Initialize the database using our enhanced resilient setup
# This handles repo startup, sandbox mode configuration, and ETS tables
XIAM.ResilientDatabaseSetup.initialize_test_environment()

# Double-check that repo is properly initialized with diagnostic output
case XIAM.ResilientDatabaseSetup.repository_status(XIAM.Repo) do
  {:ok, _pid} -> 
    IO.puts("✅ Repository successfully initialized for tests")
  status -> 
    IO.warn("⚠️ Repository initialization issue: #{inspect(status)}")
end

# Explicitly check that the repo is accessible
try do
  XIAM.Repo.__adapter__()
rescue
  _ -> 
    IO.warn("⚠️ Repo is not properly initialized in test_helper.exs")
end

# Detect Oban worker modules for reference
_workers =
  :xiam
  |> Application.spec(:modules)
  |> Enum.filter(fn module ->
    module |> to_string() |> String.contains?("Worker") &&
    Code.ensure_loaded?(module) &&
    function_exported?(module, :perform, 1)
  end)

# We don't need to drain the queue because we're using a clean test database
# and we've disabled Oban's job processing
