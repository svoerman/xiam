defmodule XIAM.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use XIAM.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias XIAM.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import XIAM.DataCase
    end
  end

  setup tags do
    XIAM.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    # Ensure the application is started with the repo
    {:ok, _} = Application.ensure_all_started(:xiam)

    # Make sure the repo is properly started - this is critical
    # to ensure database operations work correctly
    case Process.whereis(XIAM.Repo) do
      nil ->
        # Repo is not started, try to start it explicitly
        {:ok, _} = Application.ensure_all_started(:ecto_sql)
        {:ok, _} = XIAM.Repo.start_link([])
      _ -> 
        :ok
    end
    
    # Add more robust error handling around the sandbox setup
    try do
      # Determine if shared mode should be used (for non-async tests)
      shared_mode = not tags[:async]
      
      # Use a more conservative timeout value
      timeout = 60_000
      
      # Insert an explicit delay to let the database connection stabilize
      Process.sleep(100)
      
      pid = Ecto.Adapters.SQL.Sandbox.start_owner!(
        XIAM.Repo, 
        shared: shared_mode,
        timeout: timeout
      )
      
      # Ensure the connection is properly cleaned up
      on_exit(fn -> 
        try do
          Ecto.Adapters.SQL.Sandbox.stop_owner(pid)
        rescue
          e -> 
            IO.warn("Error cleaning up sandbox: #{inspect(e)}")
            :ok
        end
      end)
    rescue
      e -> 
        IO.warn("Error setting up sandbox: #{inspect(e)}")
        # Try a fallback approach - check if repo is running first
        case Process.whereis(XIAM.Repo) do
          nil ->
            # Try to manually start it one more time if we can
            try do
              {:ok, _} = Application.ensure_all_started(:ecto_sql)
              {:ok, _} = XIAM.Repo.start_link([])
              Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
              on_exit(fn -> 
                try do 
                  Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, :manual) 
                catch
                  _, _ -> :ok
                end
              end)
            rescue
              _ -> 
                # We tried our best
                :ok
            end
          pid when is_pid(pid) ->
            # Repo is running, try to set sandbox mode
            try do
              Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
              on_exit(fn -> 
                try do 
                  Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, :manual) 
                catch
                  _, _ -> :ok
                end
              end)
            rescue
              _ -> :ok
            end
        end
    end
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
