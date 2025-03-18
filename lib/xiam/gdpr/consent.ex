defmodule XIAM.GDPR.Consent do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, warn: false

  schema "consent_records" do
    field :consent_type, :string
    field :consent_given, :boolean, default: false
    field :ip_address, :string
    field :user_agent, :string
    field :revoked_at, :utc_datetime
    
    belongs_to :user, XIAM.Users.User

    timestamps()
  end

  @doc false
  def changeset(consent, attrs) do
    consent
    |> cast(attrs, [:consent_type, :consent_given, :ip_address, :user_agent, :user_id, :revoked_at])
    |> validate_required([:consent_type, :consent_given, :user_id])
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Records a new consent record for a user.
  """
  def record_consent(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> XIAM.Repo.insert()
  end

  @doc """
  Revokes a specific consent for a user.
  """
  def revoke_consent(consent_id, revocation_attrs) do
    __MODULE__
    |> XIAM.Repo.get(consent_id)
    |> changeset(Map.merge(revocation_attrs, %{revoked_at: DateTime.utc_now()}))
    |> XIAM.Repo.update()
  end

  @doc """
  Gets all consent records for a user.
  """
  def get_user_consents(user_id) do
    __MODULE__
    |> where([c], c.user_id == ^user_id)
    |> XIAM.Repo.all()
  end

  @doc """
  Checks if a user has given consent for a specific type.
  Returns true if valid consent exists, false otherwise.
  """
  def has_valid_consent?(user_id, consent_type) do
    __MODULE__
    |> where([c], c.user_id == ^user_id and c.consent_type == ^consent_type and c.consent_given == true and is_nil(c.revoked_at))
    |> XIAM.Repo.exists?()
  end
end
