defmodule XIAM.Auth.WebAuthn do
  @moduledoc """
  Handles WebAuthn (passkey) operations for user authentication.
  This module provides functions for registering and authenticating passkeys.
  """
  
  alias XIAM.Users.User
  alias XIAM.Auth.UserPasskey
  alias XIAM.Repo
  import Ecto.Query

  # Constants for WebAuthn configuration
  @rp_id "localhost"
  @rp_origin "http://localhost:4000"
  @rp_name "XIAM"
  
  @doc """
  Generates registration options for creating a new passkey.
  
  ## Parameters
  - `user`: The user for whom to generate registration options
  
  ## Returns
  - `{options, challenge}` tuple
  """
  def generate_registration_options(%User{} = user) do
    # Create a new registration challenge
    authenticator_selection = %{
      authenticator_attachment: "platform",
      resident_key: "preferred",
      user_verification: "preferred"
    }
    challenge = Wax.new_registration_challenge(
      rp_id: @rp_id,
      user_id: <<user.id::unsigned-integer-size(64)>>,
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
        id: Base.url_encode64(<<user.id::unsigned-integer-size(64)>>, padding: false),
        name: user.email,
        displayName: user.name || user.email
      },
      pubKeyCredParams: [
        %{type: "public-key", alg: -7},  # ES256
        %{type: "public-key", alg: -257} # RS256
      ],
      timeout: challenge.timeout,
      attestation: challenge.attestation,
      authenticatorSelection: authenticator_selection
    }
    
    {options, challenge}
  end
  
  @doc """
  Verifies a registration attestation and creates a new passkey.
  
  ## Parameters
  - `user`: The user for whom to verify registration
  - `attestation`: The attestation response from the client
  - `challenge`: The challenge sent to the client
  - `friendly_name`: A friendly name for the passkey
  
  ## Returns
  - `{:ok, passkey}` if registration is successful
  - `{:error, reason}` if registration fails
  """
  def verify_registration(%User{} = user, attestation, challenge, friendly_name) when is_map(attestation) do
    try do
      # Process the attestation
      case process_registration(attestation, challenge) do
        {:ok, credential_info} ->
          # Create a new passkey
          %UserPasskey{}
          |> UserPasskey.changeset(%{
            user_id: user.id,
            credential_id: credential_info.credential_id,
            public_key: encode_public_key(credential_info.public_key),
            sign_count: credential_info.sign_count,
            friendly_name: friendly_name,
            aaguid: credential_info.aaguid
          })
          |> Repo.insert()
          
        {:error, reason} -> 
          {:error, reason}
      end
    rescue
      e -> 
        IO.puts("Registration error: #{inspect(e)}")
        {:error, "Registration failed: #{inspect(e)}"}
    end
  end
  
  # Handle string inputs
  def verify_registration(user, attestation, challenge, friendly_name) when is_binary(attestation) do
    case Jason.decode(attestation) do
      {:ok, decoded} -> verify_registration(user, decoded, challenge, friendly_name)
      {:error, _} -> {:error, "Invalid attestation format: expected JSON object"}
    end
  end

  # Process registration attestation
  defp process_registration(%{"attestationObject" => attestation_object, "clientDataJSON" => client_data_json}, challenge) do
    try do
      # Decode the attestation object and client data JSON
      client_data_hash = :crypto.hash(:sha256, client_data_json)
      
      # Use Wax library to register the credential
      case Wax.register(attestation_object, client_data_json, challenge) do
        {:ok, {%Wax.AuthenticatorData{attested_credential_data: cred_data}, _}} when not is_nil(cred_data) ->
          IO.puts("Registration successful!")
          
          # Extract the credential data
          {:ok, %{
            credential_id: cred_data.credential_id,
            public_key: cred_data.credential_public_key,
            aaguid: cred_data.aaguid,
            sign_count: 0
          }}
          
        {:ok, {nil, fmt}} ->
          IO.puts("Received nil credential data with format: #{fmt}")
          
          # Try to extract from attestation directly
          parsed_attestation = case CBOR.decode(Base.url_decode64!(attestation_object, padding: false)) do
            {:ok, decoded, _} -> decoded
            _ -> nil
          end
          
          # Try to extract credential info from attestation
          extract_credential_from_attestation(parsed_attestation, client_data_hash)
          
        {:error, reason} ->
          IO.puts("Registration failed: #{inspect(reason)}")
          {:error, "Registration failed: #{inspect(reason)}"}
      end
    rescue
      e -> 
        IO.puts("Error in process_registration: #{inspect(e)}")
        {:error, "Registration error: #{inspect(e)}"}
    end
  end
  
  # Helper function to extract credential info manually from attestation object
  defp extract_credential_from_attestation(nil, _client_data_hash), do: {:error, "Invalid attestation object"}
  defp extract_credential_from_attestation(attestation, _client_data_hash) do
    try do
      # Extract from auth_data in the CBOR-decoded attestation
      with %{"fmt" => _fmt, "authData" => auth_data} <- attestation,
           << _rpid_hash::binary-size(32), flags::binary-size(1), counter::binary-size(4), credential_data::binary >> <- auth_data do
        
        # Check if attestation data is present (bit 6 of flags)
        <<_::5, at::1, _::2>> = flags
        
        if at == 1 do
          # Extract credential data (aaguid, credential id length, credential id, public key)
          << aaguid::binary-size(16), id_len::unsigned-16, rest::binary >> = credential_data
          << credential_id::binary-size(id_len), public_key_cbor::binary >> = rest
          
          # Decode the public key (just to validate it)
          _public_key = CBOR.decode(public_key_cbor)
          
          # Convert counter to integer
          <<sign_count::unsigned-32>> = counter
          
          {:ok, %{
            credential_id: credential_id,
            public_key: public_key_cbor,  # Store CBOR-encoded key
            aaguid: aaguid,
            sign_count: sign_count
          }}
        else
          {:error, "Attestation data not present in auth_data"}
        end
      else
        _ -> {:error, "Invalid attestation format"}
      end
    rescue
      e -> {:error, "Error extracting credential: #{inspect(e)}"}
    end
  end
  
  # Encode public key to binary format before storing
  defp encode_public_key(public_key) when is_map(public_key) do
    try do
      # Use CBOR to encode the public key map to binary
      CBOR.encode(public_key)
    rescue
      e -> 
        # Log the error and create a placeholder binary
        IO.puts("Error encoding public key: #{inspect(e)}")
        <<0>>
    end
  end
  
  # Handle case where public key might already be binary
  defp encode_public_key(public_key) when is_binary(public_key), do: public_key
  
  # Fallback for unexpected types
  defp encode_public_key(_), do: <<0>>
  
  @doc """
  Generates authentication options for passkey authentication.
  
  ## Parameters
  - `email`: Optional user email to filter passkeys
  
  ## Returns
  - `{options, challenge}` tuple
  """
  def generate_authentication_options(email \\ nil) do
    allow_credentials = 
      if email do
        IO.puts("Generating auth options for email: #{email}")
        case Repo.one(from u in User, where: u.email == ^email) do
          %User{id: id} ->
            passkeys = UserPasskey.list_by_user(id)
            IO.puts("Found #{length(passkeys)} passkeys for user")
            
            # Convert credential IDs to the correct format for Wax challenges
            Enum.map(passkeys, fn passkey -> 
              # Encode as Base64URL for the browser
              encoded_id = Base.url_encode64(passkey.credential_id, padding: false)
              IO.puts("Adding credential_id: #{encoded_id} (#{byte_size(passkey.credential_id)} bytes)")
              
              %{
                id: encoded_id,  # Use the Base64URL encoded ID here for the browser
                type: "public-key"
              }
            end)
          _ -> 
            IO.puts("No user found for email: #{email}")
            []
        end
      else
        # Empty array - we should use generate_authentication_options_with_all_passkeys instead
        # when no email is provided
        []
      end
    
    # Generate challenge
    challenge = Wax.new_authentication_challenge(
      rp_id: @rp_id,
      origin: @rp_origin,
      allow_credentials: allow_credentials
    )
    
    # Log for debugging
    # IO.puts("Authentication challenge created with #{length(allow_credentials)} credentials allowed")
    
    # Return options for browser and challenge for verification
    {build_auth_options(challenge, allow_credentials), challenge}
  end
  
  @doc """
  Generate authentication options for true usernameless authentication.
  This approach doesn't send any credential IDs to the browser and relies on
  server-side filtering for validation, making it highly scalable for many users.
  
  ## Returns
  - `{options, challenge}` tuple configured for usernameless authentication
  """
  def generate_authentication_options_with_all_passkeys() do
    # Set empty allow_credentials for usernameless authentication
    # This is the key for scalability - we don't send ANY credential IDs to the browser
    allow_credentials = []
    
    # Generate challenge without credential restrictions
    # This lets the browser present ANY credential to the server
    challenge = Wax.new_authentication_challenge(
      rp_id: @rp_id,
      origin: @rp_origin,
      # Empty allow_credentials enables true usernameless authentication
      allow_credentials: allow_credentials
    )
    
    # Log for debugging
    IO.puts("Creating TRUE usernameless authentication challenge")
    IO.puts("No credential allowlist sent to browser - will validate server-side")
    
    # Return browser options and challenge for verification
    {build_auth_options(challenge, allow_credentials), challenge}
  end
  
  # Build browser-friendly authentication options
  defp build_auth_options(challenge, allow_credentials) do
    # Build JSON-friendly options map
    %{
      challenge: Base.url_encode64(challenge.bytes, padding: false),
      timeout: challenge.timeout,
      rpId: challenge.rp_id,
      allowCredentials: allow_credentials,
      userVerification: challenge.user_verification
    }
  end
  
  @doc """
  Verifies the authentication assertion returned from the client.
  
  ## Parameters
  - `assertion`: The assertion response from the client
  - `challenge`: The challenge sent to the client
  
  ## Returns
  - `{:ok, user}` if the assertion is valid
  - `{:error, reason}` if the assertion is invalid
  """
  def verify_authentication(assertion, challenge) when is_map(assertion) do
    try do
      with {:ok, decoded} <- decode_assertion(assertion),
           {:ok, auth_data} <- authenticate_credential(decoded, challenge),
           {:ok, user} <- get_and_update_user(decoded.credential_id, auth_data) do
        {:ok, user}
      else
        {:error, reason} -> {:error, reason}
      end
    rescue
      e -> 
        IO.puts("Authentication error: #{inspect(e)}")
        {:error, "Authentication failed: #{inspect(e)}"}
    end
  end
  
  # Handle string inputs (JSON)
  def verify_authentication(assertion, challenge) when is_binary(assertion) do
    case Jason.decode(assertion) do
      {:ok, decoded} -> verify_authentication(decoded, challenge)
      {:error, _} -> {:error, "Invalid assertion format: expected JSON object"}
    end
  end
  
  # Fallback for invalid inputs
  def verify_authentication(_assertion, _challenge) do
    {:error, "Invalid assertion format"}
  end
  
  # Decode and validate the assertion data for various formats
  
  # Handle the nested response format from browsers (modern WebAuthn API)
  defp decode_assertion(%{"id" => credential_id, "response" => response, "type" => "public-key"}) 
       when is_map(response) do
    try do
      %{
        "authenticatorData" => authenticator_data,
        "clientDataJSON" => client_data_json,
        "signature" => signature
      } = response
      
      # Extract userHandle if available but it's optional
      user_handle = Map.get(response, "userHandle")
      
      # Log raw credential details for debugging
      IO.puts("Processing assertion with ID: #{credential_id}")
      
      # Store both versions of the credential ID
      # 1. Binary decoded version for Wax.authenticate
      # 2. Original base64 string for DB lookup
      {:ok, %{
        credential_id: Base.url_decode64!(credential_id, padding: false),
        raw_credential_id: credential_id,
        authenticator_data: authenticator_data,
        signature: signature,
        client_data_json: client_data_json,
        user_handle: user_handle
      }}
    rescue
      e -> 
        IO.puts("Error decoding assertion: #{inspect(e)}")
        {:error, "Error decoding assertion: #{inspect(e)}"}
    end
  end
  
  # Handle fallback format for assertions without nested response
  defp decode_assertion(%{"id" => credential_id, "authenticatorData" => authenticator_data,
                         "signature" => signature, "clientDataJSON" => client_data_json}) do
    try do
      # Log raw credential details for debugging
      IO.puts("Processing assertion with legacy format, ID: #{credential_id}")
      
      # Store both versions of the credential ID
      # 1. Binary decoded version for Wax.authenticate
      # 2. Original base64 string for DB lookup
      {:ok, %{
        credential_id: Base.url_decode64!(credential_id, padding: false),
        raw_credential_id: credential_id,
        authenticator_data: authenticator_data,
        signature: signature,
        client_data_json: client_data_json,
        user_handle: nil
      }}
    rescue
      e -> 
        IO.puts("Error decoding assertion: #{inspect(e)}")
        {:error, "Error decoding assertion: #{inspect(e)}"}
    end
  end
  
  # Handle invalid assertion formats
  defp decode_assertion(assertion) do
    IO.puts("Invalid assertion format: #{inspect(assertion)}")
    {:error, "Missing required assertion fields"}
  end
  
  # Authenticate the credential against the stored challenge
  defp authenticate_credential(%{credential_id: credential_id, authenticator_data: authenticator_data, 
                               signature: signature, client_data_json: client_data_json}, challenge) do
    # Ensure credential_id is binary (it should already be after decoding from Base64URL)
    if not is_binary(credential_id) or byte_size(credential_id) == 0 do
      IO.puts("ERROR: Invalid credential_id format: #{inspect(credential_id)}")
      {:error, "Invalid credential ID format"}
    else
      IO.puts("Authenticating with credential_id: #{byte_size(credential_id)} bytes")
      
      # Get authenticator data binary
      auth_data_binary = Base.url_decode64!(authenticator_data, padding: false)
      
      # Get signature binary
      signature_binary = Base.url_decode64!(signature, padding: false)
      
      # Log sizes for debugging
      IO.puts("Auth data: #{byte_size(auth_data_binary)} bytes")
      IO.puts("Signature: #{byte_size(signature_binary)} bytes")
      IO.puts("Client data: #{byte_size(client_data_json)} bytes")
      
      try do
        # Authenticate using Wax
        case Wax.authenticate(challenge, credential_id, auth_data_binary, signature_binary, client_data_json) do
          {:ok, auth_data} -> 
            {:ok, auth_data}
            
          {:error, reason} ->
            IO.puts("Authentication failed: #{inspect(reason)}")
            {:error, "Authentication failed: #{inspect(reason)}"}
        end
      catch
        kind, error ->
          IO.puts("Caught error during authentication: #{inspect(kind)}, #{inspect(error)}")
          {:error, "Error during authentication"}
      end
    end
  end
  
  # Get user and update sign_count
  defp get_and_update_user(credential_id, auth_data) do
    # Fallback for older format without raw_credential_id
    IO.puts("Using legacy get_and_update_user with binary credential_id only")
    IO.puts("Credential ID size: #{byte_size(credential_id)} bytes")
    
    # Use our new flexible finder that tries multiple formats
    case UserPasskey.find_by_credential_id_flexible(credential_id) do
      %UserPasskey{user: user} = passkey ->
        IO.puts("✅ Found passkey for user: #{user.email || "<no email>"}")
        
        # Update the sign count if it increased (security feature) and last_used_at field
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        updates = %{
          sign_count: max(auth_data.sign_count, passkey.sign_count),
          last_used_at: now
        }
        
        IO.puts("Updating sign count from #{passkey.sign_count} to #{max(auth_data.sign_count, passkey.sign_count)}")

        # Update passkey record with new sign count and last used timestamp
        updated_passkey = 
        UserPasskey.changeset(passkey, updates)
        |> Repo.update()

        IO.puts("Passkey updated: #{inspect(updated_passkey)}")
        
        # Get user and return
        user = Repo.get(User, passkey.user_id)
        
        if user do
          {:ok, user}
        else
          {:error, "User not found"}
        end
        
      nil ->
        # No matching passkey found
        IO.puts("❌ No matching passkey found in database")
        {:error, "Passkey not found"}
    end
  end
end
