defmodule XIAM.Workers.HealthCheckWorker do
  @moduledoc """
  Oban worker for performing periodic health checks.
  This worker runs at scheduled intervals to check system health
  and stores the results for monitoring purposes.
  """
  use Oban.Worker, queue: :background, max_attempts: 3

  alias XIAM.System.Health
  alias XIAM.Repo
  
  @impl Oban.Worker
  def perform(_job) do
    # Perform health check
    health_data = Health.check_health()
    
    # Store health check data in database for historical tracking
    store_health_check(health_data)
    
    # Log any issues detected
    log_health_issues(health_data)
    
    :ok
  end
  
  @doc """
  Schedules a health check job.
  """
  def schedule() do
    %{id: "health_check"}
    |> __MODULE__.new()
    |> Oban.insert()
  end
  
  # Private function to store health check data
  defp store_health_check(health_data) do
    timestamp = DateTime.truncate(DateTime.utc_now(), :second)
    
    data = %{
      timestamp: timestamp,
      database_status: health_data.database.status,
      application_status: health_data.application.status,
      memory_total: health_data.memory.total,
      disk_available: health_data.disk[:available],
      disk_used_percent: health_data.disk[:used_percent],
      node_count: health_data.cluster.node_count,
      process_count: health_data.system_info.process_count
    }
    
    Repo.insert_all("system_health_checks", [data], on_conflict: :nothing)
  end
  
  # Private function to log health issues
  defp log_health_issues(health_data) do
    issues = []
    
    # Check for database issues
    issues = if health_data.database.status != :ok do
      [%{component: "database", status: health_data.database.status, details: health_data.database} | issues]
    else
      issues
    end
    
    # Check for memory warning (> 90% usage)
    system_memory = :erlang.memory(:system)
    process_memory = :erlang.memory(:processes)
    total_memory = :erlang.memory(:total)
    
    issues = if (system_memory + process_memory) / total_memory > 0.9 do
      [%{component: "memory", status: :warning, details: health_data.memory} | issues]
    else
      issues
    end
    
    # Check for disk space warning (> 90% used)
    issues = if health_data.disk[:status] == :ok && 
               String.replace(health_data.disk[:used_percent], "%", "")
               |> String.to_integer() > 90 do
      [%{component: "disk", status: :warning, details: health_data.disk} | issues]
    else
      issues
    end
    
    # Log any detected issues
    if length(issues) > 0 do
      require Logger
      Logger.warning("Health check detected issues: #{inspect(issues)}")
    end
    
    issues
  end
end
