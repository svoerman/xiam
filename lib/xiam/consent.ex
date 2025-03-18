defmodule XIAM.Consent do
  @moduledoc """
  The Consent context manages all operations related to user consent records
  for GDPR compliance and privacy management.
  """

  import Ecto.Query
  alias XIAM.Repo
  alias XIAM.Consent.ConsentRecord
  alias XIAM.Audit

  @doc """
  Returns a list of consent records.

  ## Examples

      iex> list_consent_records()
      [%ConsentRecord{}, ...]

  """
  def list_consent_records(filters \\ %{}, page_params \\ %{}) do
    page = Map.get(page_params, :page, 1)
    per_page = Map.get(page_params, :per_page, 20)

    ConsentRecord
    |> ConsentRecord.filter_by(filters)
    |> order_by(desc: :inserted_at)
    |> preload(:user)
    |> Repo.paginate(page: page, page_size: per_page)
  end

  @doc """
  Gets a single consent_record.

  Raises `Ecto.NoResultsError` if the Consent record does not exist.

  ## Examples

      iex> get_consent_record!(123)
      %ConsentRecord{}

      iex> get_consent_record!(456)
      ** (Ecto.NoResultsError)

  """
  def get_consent_record!(id), do: Repo.get!(ConsentRecord, id) |> Repo.preload(:user)

  @doc """
  Gets the active consent record for a user and consent type.

  Returns `nil` if no active consent record exists.

  ## Examples

      iex> get_active_consent(user_id, "marketing")
      %ConsentRecord{}

      iex> get_active_consent(user_id, "non_existent")
      nil

  """
  def get_active_consent(user_id, consent_type) do
    ConsentRecord
    |> ConsentRecord.filter_by(%{user_id: user_id, consent_type: consent_type, active_only: true})
    |> Repo.one()
  end

  @doc """
  Creates a consent record.

  ## Examples

      iex> create_consent_record(%{field: value})
      {:ok, %ConsentRecord{}}

      iex> create_consent_record(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_consent_record(attrs \\ %{}, actor \\ nil, conn \\ nil) do
    result =
      %ConsentRecord{}
      |> ConsentRecord.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, record} ->
        Audit.log_action(
          "create_consent",
          actor || :system,
          "consent_record",
          record.id,
          %{
            consent_type: record.consent_type,
            consent_given: record.consent_given,
            user_id: record.user_id
          },
          conn
        )
        result
      _ ->
        result
    end
  end

  @doc """
  Updates a consent record.

  ## Examples

      iex> update_consent_record(consent_record, %{field: new_value})
      {:ok, %ConsentRecord{}}

      iex> update_consent_record(consent_record, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_consent_record(%ConsentRecord{} = consent_record, attrs, actor \\ nil, conn \\ nil) do
    result =
      consent_record
      |> ConsentRecord.changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, record} ->
        Audit.log_action(
          "update_consent",
          actor || :system,
          "consent_record",
          record.id,
          %{
            consent_type: record.consent_type,
            consent_given: record.consent_given,
            user_id: record.user_id
          },
          conn
        )
        result
      _ ->
        result
    end
  end

  @doc """
  Revokes a consent record.

  ## Examples

      iex> revoke_consent(consent_record)
      {:ok, %ConsentRecord{}}

  """
  def revoke_consent(%ConsentRecord{} = consent_record, actor \\ nil, conn \\ nil) do
    result =
      consent_record
      |> ConsentRecord.revoke_changeset()
      |> Repo.update()

    case result do
      {:ok, record} ->
        Audit.log_action(
          "revoke_consent",
          actor || :system,
          "consent_record",
          record.id,
          %{
            consent_type: record.consent_type,
            user_id: record.user_id
          },
          conn
        )
        result
      _ ->
        result
    end
  end

  @doc """
  Lists all available consent types.

  ## Examples

      iex> list_consent_types()
      [%{id: "marketing", name: "Marketing", description: "Marketing communications"}, ...]

  Returns a list of consent types with their id, name, and description.
  """
  def list_consent_types do
    [
      %{id: "marketing_emails", name: "Marketing", description: "Consent to receive marketing communications"},
      %{id: "data_processing", name: "Analytics", description: "Consent to collect analytics data"},
      %{id: "third_party_sharing", name: "Third Party", description: "Consent to share data with third parties"},
      %{id: "cookie_tracking", name: "Cookies", description: "Consent to use cookies on the website"}
    ]
  end

  @doc """
  Records a new consent or updates an existing one.

  ## Examples

      iex> record_consent(user_id, "marketing", true, conn)
      {:ok, %ConsentRecord{}}

  """
  def record_consent(user_id, consent_type, consent_given, conn \\ nil) do
    ip_address = if conn, do: conn.remote_ip |> Tuple.to_list() |> Enum.join("."), else: nil
    user_agent = if conn, do: get_in(conn.req_headers, ["user-agent"]), else: nil
    
    attrs = %{
      user_id: user_id,
      consent_type: consent_type,
      consent_given: consent_given,
      ip_address: ip_address,
      user_agent: user_agent
    }

    case get_active_consent(user_id, consent_type) do
      nil ->
        # No active consent exists, create a new one
        create_consent_record(attrs, nil, conn)
      
      existing_consent ->
        if existing_consent.consent_given != consent_given do
          # Consent state changed, update the record
          update_consent_record(existing_consent, attrs, nil, conn)
        else
          # Consent state is the same, return the existing record
          {:ok, existing_consent}
        end
    end
  end

  @doc """
  Returns raw consent type IDs for backward compatibility.
  """
  def list_consent_type_ids do
    list_consent_types()
    |> Enum.map(fn type -> type.id end)
  end

  @doc """
  Returns a list of consents for a specific user.
  """
  def get_user_consents(user_id) do
    ConsentRecord
    |> where([c], c.user_id == ^user_id)
    |> where([c], is_nil(c.revoked_at))
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Checks if a user has given consent for a specific type.
  """
  def has_user_consent?(user_id, consent_type) do
    case get_active_consent(user_id, consent_type) do
      %ConsentRecord{consent_given: true} -> true
      _ -> false
    end
  end
end
