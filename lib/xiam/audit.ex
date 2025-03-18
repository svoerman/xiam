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
    user_agent = if conn, do: get_in(conn.req_headers, ["user-agent"]), else: nil

    actor_id = case actor do
      %{id: id} -> id
      _ -> nil
    end

    actor_type = case actor do
      %XIAM.Users.User{} -> "user"
      %{type: type} -> type
      _ -> "system"
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
end
