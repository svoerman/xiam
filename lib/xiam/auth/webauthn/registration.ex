defmodule XIAM.Auth.WebAuthn.Registration do
  @moduledoc """
  Handles WebAuthn (passkey) registration operations.
  """

  alias XIAM.Users.User
  alias XIAM.Auth.UserPasskey
  alias XIAM.Auth.WebAuthn.Helpers
  alias XIAM.Auth.WebAuthn.CredentialExtractor
  alias XIAM.Repo
  require Logger

  # Use compile_env for configuration fetched at compile time
  @rp_id Application.compile_env(:xiam, :webauthn, [])[:rp_id] || "localhost"
  @rp_name Application.compile_env(:xiam, :webauthn, [])[:rp_name] || "XIAM"

  @doc """
  Generates registration options for creating a new passkey.

  ## Parameters
  - `user`: The user for whom to generate registration options

  ## Returns
  - `{options, challenge}` tuple
  """
  def generate_registration_options(%User{} = user, scheme, host, port) do
  # Create a new registration challenge
  authenticator_selection = %{
    authenticator_attachment: "platform",
    resident_key: "preferred",
    user_verification: "preferred"
  }

  rp_origin = "#{scheme}://#{host}:#{port}"

  challenge = Wax.new_registration_challenge(
    rp_id: @rp_id,
    rp_origin: rp_origin,
    user_id: Helpers.encode_user_id(user.id), # Use helper
    user_name: user.email,
    user_display_name: user.name || user.email,
    attestation: "none",
    authenticator_selection: authenticator_selection
  )

  # Build options for client
  options = %{
    challenge: Base.url_encode64(challenge.bytes, padding: false),
    rp: %{
      id: challenge.rp_id,
      name: @rp_name
    },
    user: %{
      id: Base.url_encode64(Helpers.encode_user_id(user.id), padding: false), # Use helper
      name: user.email,
      displayName: user.name || user.email
    },
    pubKeyCredParams: [
      %{type: "public-key", alg: -7}, # ES256
      %{type: "public-key", alg: -257} # RS256
    ],
    timeout: challenge.timeout,
    attestation: challenge.attestation,
    authenticatorSelection: authenticator_selection
  }

  {options, challenge}
end

@doc """
Backward compatible version of generate_registration_options that uses config values
for the scheme, host, and port.

Preferably use the 4-argument version directly with values from the current request.
"""
def generate_registration_options(%User{} = user) do
  # Get default values from endpoint config
  endpoint_config = Application.get_env(:xiam, XIAMWeb.Endpoint)
  host = endpoint_config[:url][:host] || "localhost"
  port = endpoint_config[:url][:port] || endpoint_config[:http][:port] || 4100
  scheme = endpoint_config[:url][:scheme] || "http"
  
  generate_registration_options(user, scheme, host, port)
end

  @doc """
  Verifies a registration attestation and creates a new passkey.

  ## Parameters
  - `user`: The user for whom to verify registration
  - `attestation`: The attestation response from the client (as map or JSON string)
  - `challenge`: The challenge sent to the client
  - `friendly_name`: A friendly name for the passkey

  ## Returns
  - `{:ok, passkey}` if registration is successful
  - `{:error, reason}` if registration fails
  """
  def verify_registration(%User{} = user, attestation, challenge, friendly_name) do
    with {:ok, decoded_attestation} <- Helpers.decode_json_input(attestation),
         {:ok, credential_info} <- process_registration(decoded_attestation, challenge),
         {:ok, passkey} <- create_passkey(user, credential_info, friendly_name) do
      {:ok, passkey}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Creates a passkey record for the user based on the extracted credential info.
  
  ## Parameters
  - `user`: The user for whom to create the passkey
  - `credential_info`: Extracted credential information
  - `friendly_name`: A friendly name for the passkey
  
  ## Returns
  - `{:ok, passkey}` if successful
  - `{:error, changeset}` if database insertion fails
  """
  def create_passkey(%User{} = user, credential_info, friendly_name) do
    %UserPasskey{}
    |> UserPasskey.changeset(%{
      user_id: user.id,
      credential_id: Base.url_encode64(credential_info.credential_id, padding: false),
      public_key: Helpers.encode_public_key(credential_info.public_key),
      sign_count: credential_info.sign_count,
      friendly_name: friendly_name,
      aaguid: credential_info.aaguid
    })
    |> Repo.insert()
  end

  # Process registration attestation using a clear pipeline of steps
  @doc false
  def process_registration(attestation_map, challenge) do
    with {:ok, decoded_data} <- decode_attestation_data(attestation_map),
         {:ok, result} <- verify_with_wax(decoded_data, challenge) do
      {:ok, result}
    end
  end

  # Decode the attestation data from the client, handling different formats
  defp decode_attestation_data(%{"attestationObject" => attestation_object, "clientDataJSON" => client_data_json}) do
    try do
      decoded_attestation = Base.url_decode64!(attestation_object, padding: false)
      decoded_client_data = Base.url_decode64!(client_data_json, padding: false)
      
      {:ok, %{
        attestation_object: decoded_attestation,
        client_data_json: decoded_client_data
      }}
    rescue
      e -> 
        Logger.error("Error decoding attestation data: #{inspect(e)}")
        {:error, "Invalid attestation encoding"}
    end
  end
  
  # Handle modern browser format with response nested key
  defp decode_attestation_data(%{"response" => %{"attestationObject" => attestation_object, 
                                               "clientDataJSON" => client_data_json}, 
                               "type" => "public-key"}) do
    decode_attestation_data(%{"attestationObject" => attestation_object, "clientDataJSON" => client_data_json})
  end
  
  defp decode_attestation_data(_invalid_format) do
    {:error, "Invalid attestation format. Expected attestationObject and clientDataJSON."}
  end

  # Verify the attestation with Wax, falling back to manual extraction if needed
  defp verify_with_wax(decoded_data, challenge) do
    case Wax.register(decoded_data.attestation_object, decoded_data.client_data_json, challenge) do
      {:ok, {%Wax.AuthenticatorData{attested_credential_data: cred_data, sign_count: sign_count}, _}} ->
        Logger.debug("Wax registration successful")
        {:ok, %{
          credential_id: cred_data.credential_id,
          public_key: cred_data.credential_public_key,
          aaguid: cred_data.aaguid,
          sign_count: sign_count
        }}
        
      {:ok, {nil, _}} ->
        Logger.warning("Wax.register returned nil credential data. Attempting manual extraction.")
        parsed_attestation = CBOR.decode(decoded_data.attestation_object)
        client_data_hash = :crypto.hash(:sha256, decoded_data.client_data_json)
        CredentialExtractor.extract_from_attestation(parsed_attestation, client_data_hash)
        
      {:error, reason} ->
        Logger.error("Wax registration failed: #{inspect(reason)}")
        {:error, "Registration failed: #{inspect(reason)}"}
    end
  rescue
    e ->
      Logger.error("Error during Wax verification: #{inspect(e)}")
      {:error, "Verification error: #{inspect(e)}"}
  end

end
