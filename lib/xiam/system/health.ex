defmodule XIAM.System.Health do
  @moduledoc """
  Health monitoring functionality for the XIAM system.
  Provides functions to check system health, database connectivity,
  memory usage, and other key metrics.
  """

  alias XIAM.Repo
  alias XIAM.Users.User
  
  @doc """
  Returns a map with system health information.
  """
  def check_health do
    %{
      database: check_database(),
      application: check_application(),
      memory: check_memory(),
      disk: check_disk(),
      cluster: check_cluster(),
      system_info: system_info(),
      timestamp: DateTime.utc_now()
    }
  end
  
  @doc """
  Checks if the database is connected and working properly.
  """
  def check_database do
    try do
      # Simple query to check DB connection
      count = Repo.aggregate(User, :count, :id)
      
      %{
        status: :ok,
        connected: true,
        user_count: count,
        version: Repo.query!("SELECT version();", []).rows |> List.first() |> List.first()
      }
    rescue
      e ->
        %{
          status: :error,
          connected: false,
          error: Exception.message(e)
        }
    end
  end
  
  @doc """
  Returns information about the application.
  """
  def check_application do
    %{
      status: :ok,
      version: Application.spec(:xiam, :vsn) || "Unknown",
      started_at: Application.get_env(:xiam, :started_at),
      uptime: System.system_time(:second) - (Application.get_env(:xiam, :started_at, System.system_time(:second)) || System.system_time(:second)),
      environment: Application.get_env(:xiam, :env) || Mix.env()
    }
  end
  
  @doc """
  Returns memory usage information.
  """
  def check_memory do
    memory = :erlang.memory()
    
    %{
      status: :ok,
      total: memory[:total],
      processes: memory[:processes],
      atom: memory[:atom],
      binary: memory[:binary],
      code: memory[:code],
      ets: memory[:ets],
      system: memory[:system]
    }
  end
  
  @doc """
  Checks disk space usage.
  """
  def check_disk do
    case System.cmd("df", ["-h", "."]) do
      {output, 0} ->
        [_header | [line | _]] = String.split(output, "\n")
        [_fs, size, used, avail, used_percent | _] = String.split(line, " ", trim: true)
        
        %{
          status: :ok,
          size: size,
          used: used,
          available: avail,
          used_percent: used_percent
        }
      {_, _} ->
        %{
          status: :unknown,
          error: "Could not retrieve disk information"
        }
    end
  end
  
  @doc """
  Checks the cluster status.
  """
  def check_cluster do
    nodes = [Node.self() | Node.list()]
    
    %{
      status: length(nodes) > 0 && :ok || :warning,
      current_node: Node.self(),
      nodes: nodes,
      connected_nodes: Node.list(),
      node_count: length(nodes)
    }
  end
  
  @doc """
  Returns basic system information.
  """
  def system_info do
    %{
      otp_release: :erlang.system_info(:otp_release),
      system_architecture: :erlang.system_info(:system_architecture),
      wordsize_external: :erlang.system_info({:wordsize, :external}),
      wordsize_internal: :erlang.system_info({:wordsize, :internal}),
      smp_support: :erlang.system_info(:smp_support),
      process_count: :erlang.system_info(:process_count),
      process_limit: :erlang.system_info(:process_limit),
      schedulers: :erlang.system_info(:schedulers),
      schedulers_online: :erlang.system_info(:schedulers_online)
    }
  end
end
