defmodule XIAM.Consent.ConsentRecord do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "consent_records" do
    field :consent_type, :string
    field :consent_given, :boolean, default: false
    field :ip_address, :string
    field :user_agent, :string
    field :revoked_at, :utc_datetime

    belongs_to :user, XIAM.Users.User

    timestamps()
  end

  @doc """
  Creates a changeset for consent records.
  """
  def changeset(consent_record, attrs) do
    consent_record
    |> cast(attrs, [:consent_type, :consent_given, :ip_address, :user_agent, :revoked_at, :user_id])
    |> validate_required([:consent_type, :consent_given, :user_id])
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Revoke changeset for consent records.
  """
  def revoke_changeset(consent_record) do
    consent_record
    |> change(consent_given: false, revoked_at: DateTime.truncate(DateTime.utc_now(), :second))
  end

  @doc """
  Filter query for consent records.
  """
  def filter_by(query \\ __MODULE__, filters) do
    Enum.reduce(filters, query, fn
      {:consent_type, consent_type}, query when is_binary(consent_type) ->
        where(query, [c], c.consent_type == ^consent_type)
      
      {:user_id, user_id}, query when is_binary(user_id) or is_integer(user_id) ->
        where(query, [c], c.user_id == ^user_id)
      
      {:consent_given, consent_given}, query when is_boolean(consent_given) ->
        where(query, [c], c.consent_given == ^consent_given)
      
      {:active_only, true}, query ->
        where(query, [c], is_nil(c.revoked_at) and c.consent_given == true)
      
      _, query -> query
    end)
  end
end
