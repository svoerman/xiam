{:ok, _} = Application.ensure_all_started(:phoenix_live_view)

# Ensure applications are started
{:ok, _} = Application.ensure_all_started(:ecto)
{:ok, _} = Application.ensure_all_started(:postgrex)

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

# Start necessary applications for testing
IO.puts("[TEST_HELPER] Ensuring :ecto_sql is started...")
{:ok, _} = Application.ensure_all_started(:ecto_sql)
IO.puts("[TEST_HELPER] :ecto_sql started.")

IO.puts "[TEST_HELPER] Ensuring :xiam application is started..."
case Application.ensure_all_started(:xiam) do
  {:ok, _} ->
    IO.puts "[TEST_HELPER] :xiam application started successfully."
  {:error, {app, reason}} ->
    IO.puts "[TEST_HELPER] ERROR: Failed to start :xiam application. App: #{inspect(app)}, Reason: #{inspect(reason)}"
    # Consider raising an error here to halt tests if :xiam fails to start, as it's critical.
    raise "Fatal: Failed to start :xiam application. Reason: #{inspect(reason)}"
end


# Compile the ResilientDatabaseSetup module to ensure it's available
# Code.ensure_compiled(XIAM.ResilientDatabaseSetup) # Removed for simplification

# Disable Oban for testing (before ExUnit starts)
Application.put_env(:oban, :testing, :manual)
Application.put_env(:oban, :queues, false)
Application.put_env(:oban, :plugins, false)
Application.put_env(:oban, :peer, false)
Application.put_env(:xiam, :oban_testing, true)

# Mox setup for XIAM.Users
Mox.defmock(XIAM.Users.Mock, for: XIAM.Users.Behaviour)
Application.put_env(:xiam, :users, XIAM.Users.Mock)

# Configure ExUnit with improved test pattern recognition
ExUnit.configure(
  exclude: [pending: true]
)

# Ensure TestOutputHelper is properly compiled first
# Don't use Code.require_file which causes module redefinition warnings
# Use the compiled module directly
# alias XIAM.TestOutputHelper, as: Output # Removed as it's unused

# Start ExUnit application
ExUnit.start(exclude: [:pending])

# Removed diagnostic pings and checks for simplification

# Detect Oban worker modules for reference
_workers =
  :xiam
  |> Application.spec(:modules)
  |> Enum.filter(fn module ->
    module |> to_string() |> String.contains?("Worker") &&
    Code.ensure_loaded?(module) &&
    function_exported?(module, :perform, 1)
  end)
