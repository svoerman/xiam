defmodule XIAM.AuditTest do
  use XIAM.DataCase

  alias XIAM.Audit
  alias XIAM.Audit.AuditLog
  alias XIAM.Users.User
  alias XIAM.Repo

  describe "audit logging" do
    setup do
      # Create a test user
      {:ok, user} = %User{}
        |> User.pow_changeset(%{
          email: "audit_test@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })
        |> Repo.insert()

      {:ok, user: user}
    end

    test "log_action/3 creates an audit log entry", %{user: user} do
      # Define test data
      action = "test_action"
      details = %{key: "value", number: 123}

      # Log the action
      assert {:ok, %AuditLog{} = log} = Audit.log_action(action, user, "test_resource", "123", details)
      
      # Verify log entry
      assert log.action == action
      assert log.actor_id == user.id
      assert log.metadata.key == "value"
      # Access Elixir atom keys instead of string keys
      assert log.metadata.number == 123
      assert log.resource_id == "123"
    end

    test "log_action/3 with nil user creates anonymous log entry" do
      # Define test data
      action = "anonymous_action"
      details = %{data: "test"}

      # Log the action without a user
      assert {:ok, %AuditLog{} = log} = Audit.log_action(action, nil, "test_resource", "456", details)
      
      # Verify log entry
      assert log.action == action
      assert log.actor_id == nil
      assert log.metadata.data == "test"
      assert log.resource_id == "456"
    end

    test "get_audit_log!/1 retrieves a specific log entry", %{user: user} do
      # Create a log entry
      {:ok, log} = Audit.log_action("get_test", user, "test_resource", "789", %{})
      
      # Retrieve the log entry
      retrieved_log = Audit.get_audit_log!(log.id)
      assert retrieved_log.id == log.id
      assert retrieved_log.action == "get_test"
      assert retrieved_log.actor_id == user.id
    end

    test "list_audit_logs/1 returns all logs" do
      # Get initial count
      initial_logs = Audit.list_audit_logs()
      initial_count = length(initial_logs.entries)
      
      # Add a log entry
      {:ok, _log} = Audit.log_action("list_test", nil, "test_resource", "123", %{})
      
      # Verify count increased
      logs = Audit.list_audit_logs()
      assert length(logs.entries) == initial_count + 1
    end

    test "list_audit_logs/1 with filters returns filtered logs", %{user: user} do
      # Create multiple log entries
      {:ok, _} = Audit.log_action("action1", user, "test_resource", "a", %{})
      {:ok, _} = Audit.log_action("action2", user, "test_resource", "b", %{})
      {:ok, _} = Audit.log_action("action1", nil, "test_resource", "c", %{})
      
      # Filter by action
      action1_logs = Audit.list_audit_logs(%{action: "action1"})
      assert length(action1_logs.entries) >= 2
      assert Enum.all?(action1_logs.entries, fn log -> log.action == "action1" end)
      
      # Filter by actor_id
      user_logs = Audit.list_audit_logs(%{actor_id: user.id})
      assert length(user_logs.entries) >= 2
      assert Enum.all?(user_logs.entries, fn log -> log.actor_id == user.id end)
      
      # Filter by both
      filtered_logs = Audit.list_audit_logs(%{action: "action1", actor_id: user.id})
      assert length(filtered_logs.entries) >= 1
      assert Enum.all?(filtered_logs.entries, fn log -> 
        log.action == "action1" && log.actor_id == user.id 
      end)
    end

    test "delete_logs_older_than/1 deletes old logs", %{user: user} do
      # Create a log entry
      {:ok, log} = Audit.log_action("old_test", user, "test_resource", "old", %{})
      
      # Update the inserted_at to make it old (1 day ago)
      one_day_ago = NaiveDateTime.utc_now() |> NaiveDateTime.add(-86400, :second) |> NaiveDateTime.truncate(:second)
      Repo.get!(AuditLog, log.id)
      |> Ecto.Changeset.change(inserted_at: one_day_ago)
      |> Repo.update!()
      
      # Delete logs older than now
      {deleted_count, _} = Audit.delete_logs_older_than(DateTime.utc_now())
      assert deleted_count >= 1
      
      # Verify log was deleted
      assert_raise Ecto.NoResultsError, fn -> Audit.get_audit_log!(log.id) end
    end

    test "log_system_action/2 creates a system log entry" do
      # Define test data
      action = "system_action"
      details = %{system_data: "test"}

      # Log the system action
      assert {:ok, %AuditLog{} = log} = Audit.log_system_action(action, details)
      
      # Verify log entry
      assert log.action == action
      assert log.actor_id == nil
      assert log.actor_type == "system"
      assert log.metadata.system_data == "test"
      assert log.resource_type == "system"
    end
  end
end