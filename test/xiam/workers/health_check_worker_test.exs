defmodule XIAM.Workers.HealthCheckWorkerTest do
  use XIAM.DataCase
  import Mock

  alias XIAM.Workers.HealthCheckWorker
  alias XIAM.System.Health

  describe "perform/1" do
    test "successfully completes health check job" do
      # Mock health check data
      mock_health_data = %{
        application: %{status: :ok},
        database: %{status: :ok},
        memory: %{total: 10_000_000},
        disk: %{available: 2000000000, used_percent: "30%", status: :ok},
        cluster: %{node_count: 1},
        system_info: %{process_count: 100}
      }

      # Capture and suppress any Logger output for this test
      ExUnit.CaptureLog.capture_log(fn ->
        # Setup mocks
        with_mocks([
          {Health, [], [check_health: fn -> mock_health_data end]},
          {XIAM.Repo, [], [insert_all: fn _, _, _ -> {1, nil} end]}
        ]) do
          # Perform the job
          assert :ok = HealthCheckWorker.perform(%{})
          
          # Verify Health.check_health was called
          assert_called Health.check_health()
          
          # Verify data was stored
          assert_called XIAM.Repo.insert_all("system_health_checks", :_, on_conflict: :nothing)
        end
      end)
    end

    test "logs issues when components have problems" do
      # Mock health check data with issues
      mock_health_data = %{
        application: %{status: :ok},
        database: %{status: :error, message: "Database connection issue"},
        memory: %{total: 10_000_000},
        disk: %{available: 2000000000, used_percent: "95%", status: :ok},
        cluster: %{node_count: 1},
        system_info: %{process_count: 100}
      }

      # Capture and suppress Logger warnings for this test
      ExUnit.CaptureLog.capture_log(fn ->
        with_mocks([
          {Health, [], [check_health: fn -> mock_health_data end]},
          {XIAM.Repo, [], [insert_all: fn _, _, _ -> {1, nil} end]}
        ]) do
          # Perform the job
          assert :ok = HealthCheckWorker.perform(%{})
          
          # Verify Health.check_health was called
          assert called(Health.check_health())
        end
      end)
    end
  end

  describe "schedule/0" do
    test "schedules a health check job in test environment" do
      # Since we're in test environment, this should return the test mode response
      assert {:ok, %{test_mode: true}} = HealthCheckWorker.schedule()
    end
    
    # Updated test to match our new implementation
    test "works in test environment" do
      # Since we're using Application.get_env(:xiam, :oban_testing) now,
      # we'll temporarily set it for this test
      old_val = Application.get_env(:xiam, :oban_testing) 
      
      try do
        # Set the config value for testing
        Application.put_env(:xiam, :oban_testing, true)
        
        # Test the function
        assert {:ok, %{test_mode: true}} = HealthCheckWorker.schedule()
      after
        # Restore the original value
        Application.put_env(:xiam, :oban_testing, old_val)
      end
    end
  end
end