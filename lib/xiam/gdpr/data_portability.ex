defmodule XIAM.GDPR.DataPortability do
  @moduledoc """
  Handles GDPR data portability requirements by providing functionality to export user data.
  """
  alias XIAM.Users.User
  alias XIAM.GDPR.Consent
  alias XIAM.Repo

  @doc """
  Exports all data related to a user in JSON format.
  Returns a map structure that can be converted to JSON.
  """
  def export_user_data(user_id) when is_integer(user_id) do
    user = Repo.get!(User, user_id) |> Repo.preload([:role, :user_identities])
    
    # Basic user data (excluding sensitive fields)
    user_data = %{
      id: user.id,
      email: user.email,
      inserted_at: user.inserted_at,
      updated_at: user.updated_at,
      mfa_enabled: user.mfa_enabled,
      role: user.role && %{id: user.role.id, name: user.role.name}
    }
    
    # Get consent records
    consents = Consent.get_user_consents(user_id)
    consent_data = Enum.map(consents, fn consent ->
      %{
        consent_type: consent.consent_type,
        consent_given: consent.consent_given,
        given_at: consent.inserted_at,
        revoked_at: consent.revoked_at
      }
    end)
    
    # Get social identities (from PowAssent)
    identities_data = Enum.map(user.user_identities, fn identity ->
      %{
        provider: identity.provider,
        uid: identity.uid,
        inserted_at: identity.inserted_at,
        updated_at: identity.updated_at
      }
    end)
    
    # Combine all data into a single structure
    %{
      user: user_data,
      consents: consent_data,
      identities: identities_data
    }
  end
  
  @doc """
  Exports user data as a JSON file and returns the path to the file.
  The file is created in the tmp directory with a unique name.
  """
  def export_user_data_to_file(user_id) do
    data = export_user_data(user_id)
    json = Jason.encode!(data, pretty: true)
    
    file_name = "user_data_export_#{user_id}_#{DateTime.utc_now() |> DateTime.to_unix()}.json"
    path = Path.join(System.tmp_dir!(), file_name)
    
    File.write!(path, json)
    
    # Log this action for audit purposes
    XIAM.Jobs.AuditLogger.log_action("data_export", user_id, %{file_name: file_name}, "N/A")
    
    {:ok, path}
  end
end
