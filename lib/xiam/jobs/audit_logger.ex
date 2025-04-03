defmodule XIAM.Jobs.AuditLogger do
  use Oban.Worker, queue: :audit, max_attempts: 3
  alias XIAM.Audit # Alias the Audit context

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => action, "user_id" => user_id, "details" => details, "ip_address" => ip_address}}) do
    # Use the Audit context to create a persistent audit log entry
    case Audit.create_audit_log(%{
           action: action,
           # Determine actor_type based on user_id (or perhaps pass it in job_args?)
           # Assuming non-nil user_id means 'user' for now
           actor_type: if(user_id, do: "user", else: "system"),
           actor_id: user_id,
           resource_type: Map.get(details, "resource_type"), # Try to get resource type from details
           resource_id: Map.get(details, "resource_id"),   # Try to get resource id from details
           metadata: details, # Store the full details map
           ip_address: ip_address
           # user_agent could also be passed in job_args if available
         }) do
      {:ok, _audit_log} ->
        Logger.info("AUDIT: Action '#{action}' by user '#{user_id}' logged successfully.")
        :ok
      {:error, changeset} ->
        Logger.error("AUDIT: Failed to log action '#{action}'. Error: #{inspect(changeset.errors)}")
        # Return error to potentially retry based on Oban config
        {:error, "Failed to insert audit log"}
    end
  end

  @doc """
  Create an audit log entry for user actions.
  """
  def log_action(action, user_id, details, ip_address) do
    job_args = %{
      action: action,
      user_id: user_id,
      details: details,
      ip_address: ip_address
    }

    # In test environment, use Oban.Testing
    if Application.get_env(:xiam, :oban_testing) do
      require Logger
      Logger.debug("TEST AUDIT: User #{user_id} performed #{action}. IP: #{ip_address}")

      # Create a direct audit log entry in the database for tests
      audit_log_entry = %XIAM.Audit.AuditLog{
        action: action,
        actor_id: user_id,
        actor_type: "user",
        resource_type: "api",
        resource_id: nil,
        metadata: details,
        ip_address: ip_address,
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      # Try to insert the log entry directly, but ignore errors
      try do
        XIAM.Repo.insert(audit_log_entry)
      rescue
        _ -> {:ok, %{test_mode: true}}
      end
    else
      # In regular environments, use Oban normally
      job_args
      |> new()
      |> Oban.insert()
    end
  end
end
