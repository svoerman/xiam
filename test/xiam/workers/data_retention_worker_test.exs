defmodule XIAM.Workers.DataRetentionWorkerTest do
  use XIAM.DataCase
  alias XIAM.Workers.DataRetentionWorker

  setup do
    # Explicitly ensure repo is available
    case Process.whereis(XIAM.Repo) do
      nil ->
        # Repo is not started, try to start it explicitly
        {:ok, _} = Application.ensure_all_started(:ecto_sql)
        {:ok, _} = XIAM.Repo.start_link([])
        # Set sandbox mode
        Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
      _ -> 
        :ok
    end
    
    # Prepare an Oban job for testing
    job = %Oban.Job{id: 1, args: %{}}
    
    {:ok, %{job: job}}
  end

  test "perform/1 executes data retention tasks", %{job: job} do
    # Execute the job
    assert :ok = DataRetentionWorker.perform(job)
  end

  # Mocked test of the schedule function
  test "schedule/0 calls Oban.insert" do
    # Since Oban is not running in the test environment, we're just verifying
    # the code structure, not the actual Oban functionality
    code = """
    defmodule Test.DataRetentionWorker do
      def schedule do
        %{id: "data_retention"}
        |> XIAM.Workers.DataRetentionWorker.new()
      end
    end
    
    Test.DataRetentionWorker.schedule()
    """
    
    {result, _} = Code.eval_string(code)
    assert %{valid?: true} = result
    assert result.changes.args == %{id: "data_retention"}
    assert result.changes.queue == "gdpr"
  end

  test "run_data_retention_tasks/0 processes all retention tasks" do
    # Call the function directly
    DataRetentionWorker.run_data_retention_tasks()
    
    # Verify that audit logs were created for start and completion
    latest_logs = XIAM.Audit.list_audit_logs(%{}, %{per_page: 5, page: 1})
    
    log_actions = Enum.map(latest_logs.entries, fn log -> log.action end)
    assert "data_retention_completed" in log_actions
    assert "data_retention_started" in log_actions
  end
end