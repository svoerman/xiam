# Oban test helper is loaded automatically - don't require it explicitly

# Make sure the application is started before tests
Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto)
Application.ensure_all_started(:xiam)

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

# Configure ExUnit 
ExUnit.configure(exclude: [pending: true])
ExUnit.start()

# Ensure the repo is properly started
repo_pid = Process.whereis(XIAM.Repo)
unless is_pid(repo_pid) and Process.alive?(repo_pid) do
  {:ok, _} = XIAM.Repo.start_link([])
end

# Configure sandbox mode for Ecto
Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, :manual)

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
