defmodule XIAM.Audit do
  @moduledoc """
  The Audit context manages all operations related to audit logging and
  maintaining a record of system activities for compliance and security.
  """

  import Ecto.Query
  alias XIAM.Repo
  alias XIAM.Audit.AuditLog

  @doc """
  Returns a list of audit logs.

  ## Examples

      iex> list_audit_logs()
      [%AuditLog{}, ...]

  """
  def list_audit_logs(filters \\ %{}, page_params \\ %{}) do
    page = Map.get(page_params, :page, 1)
    per_page = Map.get(page_params, :per_page, 20)

    AuditLog
    |> AuditLog.filter_by(filters)
    |> order_by(desc: :inserted_at)
    |> preload(:actor)
    |> Repo.paginate(page: page, page_size: per_page)
  end

  @doc """
  Gets a single audit_log.

  Raises `Ecto.NoResultsError` if the Audit log does not exist.

  ## Examples

      iex> get_audit_log!(123)
      %AuditLog{}

      iex> get_audit_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_audit_log!(id), do: Repo.get!(AuditLog, id) |> Repo.preload(:actor)

  @doc """
  Creates an audit log.

  ## Examples

      iex> create_audit_log(%{field: value})
      {:ok, %AuditLog{}}

      iex> create_audit_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_audit_log(attrs \\ %{}) do
    %AuditLog{}
    |> AuditLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Logs a user action into the audit log.

  ## Examples

      iex> log_action("update", user, "user", "123", %{name: "New Name"}, conn)
      {:ok, %AuditLog{}}

  """
  def log_action(action, actor, resource_type, resource_id \\ nil, metadata \\ %{}, conn \\ nil) do
    ip_address = if conn, do: conn.remote_ip |> Tuple.to_list() |> Enum.join("."), else: nil

    # Extract user agent from req_headers list of tuples
    user_agent = if conn && conn.req_headers do
      Enum.find_value(conn.req_headers, fn
        {"user-agent", value} -> value
        _ -> nil
      end)
    else
      nil
    end

    actor_id = case actor do
      %{id: id} -> id
      _ -> nil
    end

    actor_type = case actor do
      %XIAM.Users.User{} -> "user"
      %{type: type} -> type
      _ -> "system"
    end

    # Ensure metadata is an Elixir map (keys remain strings).
    metadata = if is_map(metadata) do
      metadata
      |> Enum.map(fn
        # Avoid converting arbitrary strings to atoms for security (DoS risk).
        # Tests should handle string keys if necessary.
        {key, value} -> {key, value}
      end)
      |> Map.new()
    else
      %{}
    end

    create_audit_log(%{
      action: action,
      actor_id: actor_id,
      actor_type: actor_type,
      resource_type: resource_type,
      resource_id: "#{resource_id}",
      metadata: metadata,
      ip_address: ip_address,
      user_agent: user_agent
    })
  end

  @doc """
  Returns a list of distinct actions from audit logs.
  """
  def list_distinct_actions do
    Repo.all(from a in AuditLog, select: a.action, distinct: true)
  end

  @doc """
  Returns a list of distinct resource types from audit logs.
  """
  def list_distinct_resource_types do
    Repo.all(from a in AuditLog, select: a.resource_type, distinct: true)
  end

  @doc """
  Deletes audit logs older than the specified date.

  ## Examples

      iex> delete_logs_older_than(~U[2023-01-01 00:00:00Z])
      {5, nil}

  """
  def delete_logs_older_than(%DateTime{} = date) do
    Repo.delete_all(from log in AuditLog, where: log.inserted_at < ^date)
  end

  @doc """
  Logs a system action without a specific actor.

  ## Examples

      iex> log_system_action("system_startup", %{version: "1.0.0"})
      {:ok, %AuditLog{}}

  """
  def log_system_action(action, metadata \\ %{}) do
    log_action(action, :system, "system", nil, metadata)
  end

  @doc """
  Logs an action with a specific timestamp (for testing purposes).
  """
  def log_action_with_timestamp(action, actor, resource_type, resource_id \\ nil, metadata \\ %{}, timestamp \\ nil) do
    actor_id = case actor do
      %{id: id} -> id
      _ -> nil
    end

    actor_type = case actor do
      %XIAM.Users.User{} -> "user"
      %{type: type} -> type
      _ -> "system"
    end

    attrs = %{
      action: action,
      actor_id: actor_id,
      actor_type: actor_type,
      resource_type: resource_type,
      resource_id: "#{resource_id}",
      metadata: metadata,
      ip_address: "127.0.0.1",
      user_agent: "Test Browser"
    }

    # Set the inserted_at timestamp for testing
    if timestamp do
      %AuditLog{}
      |> AuditLog.changeset(attrs)
      |> Ecto.Changeset.put_change(:inserted_at, timestamp)
      |> Repo.insert()
    else
      create_audit_log(attrs)
    end
  end
end
