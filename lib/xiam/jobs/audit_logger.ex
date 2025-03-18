defmodule XIAM.Jobs.AuditLogger do
  use Oban.Worker, queue: :audit, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => action, "user_id" => user_id, "details" => details, "ip_address" => ip_address}}) do
    # Here we'd typically store the audit log in a database table
    # For now, we'll just log it
    require Logger
    Logger.info("AUDIT: User #{user_id} performed #{action} from #{ip_address}. Details: #{inspect(details)}")
    
    {:ok, %{success: true}}
  end

  @doc """
  Create an audit log entry for user actions.
  """
  def log_action(action, user_id, details, ip_address) do
    %{
      action: action,
      user_id: user_id, 
      details: details,
      ip_address: ip_address
    }
    |> new()
    |> Oban.insert()
  end
end
