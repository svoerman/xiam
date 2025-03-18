defmodule XIAM.Audit.AuditLog do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "audit_logs" do
    field :action, :string
    field :actor_type, :string, default: "user"
    field :resource_type, :string
    field :resource_id, :string
    field :metadata, :map, default: %{}
    field :ip_address, :string
    field :user_agent, :string

    belongs_to :actor, XIAM.Users.User

    timestamps()
  end

  @doc """
  Creates a changeset for audit logs.
  """
  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [:action, :actor_id, :actor_type, :resource_type, :resource_id, :metadata, :ip_address, :user_agent])
    |> validate_required([:action, :resource_type])
  end

  @doc """
  Returns a query for filtered audit logs.
  """
  def filter_by(query \\ __MODULE__, filters) do
    Enum.reduce(filters, query, fn
      {:action, action}, query when is_binary(action) ->
        where(query, [a], a.action == ^action)
      
      {:actor_id, actor_id}, query when is_binary(actor_id) or is_integer(actor_id) ->
        where(query, [a], a.actor_id == ^actor_id)
      
      {:resource_type, resource_type}, query when is_binary(resource_type) ->
        where(query, [a], a.resource_type == ^resource_type)
      
      {:resource_id, resource_id}, query when is_binary(resource_id) ->
        where(query, [a], a.resource_id == ^resource_id)
      
      {:date_from, date_from}, query ->
        where(query, [a], a.inserted_at >= ^date_from)
      
      {:date_to, date_to}, query ->
        where(query, [a], a.inserted_at <= ^date_to)
      
      _, query -> query
    end)
  end
end
