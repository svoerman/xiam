defmodule XIAM.System.HealthTest do
  use XIAM.DataCase

  alias XIAM.System.Health

  describe "health checks" do
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
      :ok
    end
    
    test "check_health/0 returns a complete health map" do
      health = Health.check_health()
      
      # Verify all sections are present
      assert is_map(health)
      assert is_map(health.database)
      assert is_map(health.application)
      assert is_map(health.memory)
      assert is_map(health.disk)
      assert is_map(health.cluster)
      assert is_map(health.system_info)
      assert %DateTime{} = health.timestamp
    end

    test "check_database/0 returns database status" do
      db_status = Health.check_database()
      
      assert db_status.status == :ok
      assert db_status.connected == true
      assert is_integer(db_status.user_count)
      assert is_binary(db_status.version)
    end

    test "check_application/0 returns application info" do
      app_info = Health.check_application()
      
      assert app_info.status == :ok
      assert app_info.version == "Unknown" || is_binary(app_info.version) || is_list(app_info.version)
      assert is_integer(app_info.uptime) || app_info.uptime == 0
      assert app_info.environment == :test
    end

    test "check_memory/0 returns memory usage" do
      memory = Health.check_memory()
      
      assert memory.status == :ok
      assert is_integer(memory.total)
      assert is_integer(memory.processes)
      assert is_integer(memory.atom)
      assert is_integer(memory.binary)
      assert is_integer(memory.code)
      assert is_integer(memory.ets)
    end

    test "check_disk/0 returns disk information" do
      disk = Health.check_disk()
      
      # Test will either return actual disk info or an error status
      assert Map.has_key?(disk, :status)
      if disk.status == :ok do
        assert is_binary(disk.size)
        assert is_binary(disk.used)
        assert is_binary(disk.available)
        assert is_binary(disk.used_percent)
      else
        assert disk.status == :unknown
        assert Map.has_key?(disk, :error)
      end
    end

    test "check_cluster/0 returns cluster status" do
      cluster = Health.check_cluster()
      
      assert cluster.status in [:ok, :warning]
      assert cluster.current_node == Node.self()
      assert is_list(cluster.nodes)
      assert is_list(cluster.connected_nodes)
      assert is_integer(cluster.node_count)
    end

    test "system_info/0 returns system information" do
      info = Health.system_info()
      
      # OTP release and system_architecture could be binary or charlist
      assert is_binary(info.otp_release) || is_list(info.otp_release)
      assert is_binary(info.system_architecture) || is_list(info.system_architecture)
      assert is_integer(info.wordsize_external)
      assert is_integer(info.wordsize_internal)
      assert is_boolean(info.smp_support)
      assert is_integer(info.process_count)
      assert is_integer(info.process_limit)
      assert is_integer(info.schedulers)
      assert is_integer(info.schedulers_online)
    end
  end
end