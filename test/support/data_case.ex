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
    # First ensure all required ETS tables exist
    XIAM.ETSTestHelper.ensure_ets_tables_exist()
    
    # Then set up the database sandbox
    XIAM.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    # This process-based mutex helps avoid race conditions when multiple tests
    # try to set up the sandbox concurrently
    sandbox_mutex_name = :sandbox_setup_mutex
    
    # Create a process-registry based mutex if it doesn't exist
    case Process.whereis(sandbox_mutex_name) do
      nil ->
        # Create a mutex process if it doesn't exist - start with unlocked state (false)
        pid = spawn(fn -> mutex_loop(false) end)
        Process.register(pid, sandbox_mutex_name)
      _ ->
        :ok
    end
    
    # Acquire the mutex before proceeding
    _result = safe_mutex_call(sandbox_mutex_name, :acquire, 5000)
    
    # Ensure the application is started with the repo
    app_start_result = Application.ensure_all_started(:xiam)
    
    # Handle application start result more gracefully
    case app_start_result do
      {:ok, _} -> :ok
      {:error, {:xiam, {{:shutdown, {:failed_to_start_child, XIAM.Repo, {:already_started, _}}}, _}}} ->
        # This is expected in concurrent tests - the repo is already started
        :ok
      {:error, reason} ->
        # Log other errors but try to continue
        IO.warn("Application start error: #{inspect(reason)}, trying to proceed")
    end

    # Make sure the repo is properly started
    case Process.whereis(XIAM.Repo) do
      nil ->
        # Repo is not started, try to start it explicitly
        {:ok, _} = Application.ensure_all_started(:ecto_sql)
        
        # Try to start the repo, but handle the case where it's already started
        case XIAM.Repo.start_link([]) do
          {:ok, _} -> :ok
          {:error, {:already_started, _}} -> :ok
          other -> 
            IO.warn("Unexpected repo start result: #{inspect(other)}")
            other
        end
      _ -> 
        :ok
    end
    
    # Setup sandbox with enhanced error handling
    setup_result = try do
      # First try using start_owner! which is preferred
      try_setup_with_start_owner(tags)
    rescue
      e ->
        # If that fails, use the older shared mode approach without excessive logging
        # Only log detailed errors for unexpected failure types, not common race conditions
        case e do
          %MatchError{term: {:error, {{:badmatch, :already_shared}, _}}} ->
            # This is a common race condition in concurrent tests - don't warn
            try_setup_with_shared_mode(tags)
            
          other_error ->
            # Only log unusual errors that might indicate actual problems
            IO.warn("Unusual sandbox setup error: #{inspect(other_error)}")
            try_setup_with_shared_mode(tags)
        end
    end
    
    # Release the mutex to let other tests proceed
    safe_mutex_call(sandbox_mutex_name, :release, 1000)
    
    setup_result
  end
  
  # Helper for mutex communication with timeouts
  defp safe_mutex_call(mutex_name, message, timeout) do
    try do
      # Send message to mutex process with a reference for reply
      ref = make_ref()
      send(mutex_name, {self(), ref, message})
      
      # Wait for reply with timeout
      receive do
        {^ref, result} -> result
      after
        timeout -> 
          IO.warn("Mutex call to #{inspect(mutex_name)} timed out after #{timeout}ms")
          :timeout
      end
    rescue
      e -> 
        IO.warn("Mutex call error: #{inspect(e)}")
        :error
    end
  end
  
  # Simple mutex process loop
  defp mutex_loop(_locked = false) do
    receive do
      {from, ref, :acquire} ->
        # Mutex is free, grant access to caller
        send(from, {ref, :acquired})
        mutex_loop(true)
      {from, ref, :release} ->
        # Already unlocked, just acknowledge
        send(from, {ref, :released})
        mutex_loop(false)
      {from, ref, _other} ->
        # Unknown command
        send(from, {ref, :error})
        mutex_loop(false)
    end
  end
  
  # When mutex is locked
  defp mutex_loop(_locked = true) do
    receive do
      {from, ref, :acquire} ->
        # Mutex is locked, queue this request
        # We deliberately block this caller until mutex is released
        receive do
          :mutex_released -> 
            # Now the mutex is available
            send(from, {ref, :acquired})
            mutex_loop(true)
        end
      {from, ref, :release} ->
        # Release the mutex
        send(from, {ref, :released})
        # Notify the next waiting process if any
        send(self(), :mutex_released)
        mutex_loop(false)
      {from, ref, _other} ->
        # Unknown command
        send(from, {ref, :error})
        mutex_loop(true)
    end
  end
  
  # Try to setup using start_owner (newer approach)
  defp try_setup_with_start_owner(tags) do
    # Determine if shared mode should be used (for non-async tests)
    shared_mode = not tags[:async]
    
    # Use a more conservative timeout value
    timeout = 60_000
    
    # Wrap in try/catch to handle various Sandbox errors more gracefully
    try do
      pid = Ecto.Adapters.SQL.Sandbox.start_owner!(
        XIAM.Repo, 
        shared: shared_mode,
        timeout: timeout
      )
      
      # Ensure connection cleanup with better error handling
      on_exit(fn -> 
        try do
          Ecto.Adapters.SQL.Sandbox.stop_owner(pid)
        catch
          _kind, _error -> 
            # Less verbose warning - just silently handle the error
            # Common during concurrent tests, no need to spam the console
            :ok
        end
      end)
      
      :ok
    catch
      # Handle specific error cases more gracefully
      :error, {:already_shared, _} ->
        # This is a common case, fall through to shared mode approach
        try_setup_with_shared_mode(tags)
        
      _kind, _error ->
        # For other errors, try the shared mode approach
        try_setup_with_shared_mode(tags)
    end
  end
  
  # Try to setup using shared mode (older/fallback approach)
  defp try_setup_with_shared_mode(tags) do
    # Set mode based on whether test is async
    mode = if tags[:async], do: :manual, else: {:shared, self()}
    
    # Set the sandbox mode with robust error handling
    try do
      Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, mode)
    catch
      _kind, _error ->
        # This can happen during concurrent testing - just continue
        # No need to log errors here as it's an expected race condition
        :ok
    end
    
    # Cleanup function to run after test with improved error handling
    on_exit(fn -> 
      try do
        Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, :manual)
      catch
        _, _ -> :ok
      end
    end)
    
    :ok
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
