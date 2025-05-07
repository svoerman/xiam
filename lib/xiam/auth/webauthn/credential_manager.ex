defmodule XIAM.Auth.WebAuthn.CredentialManager do
  @moduledoc """
  Manages WebAuthn credential operations for both registration and authentication.
  
  This module handles the transformation and verification operations for WebAuthn,
  while delegating data access to the PasskeyRepository module.
  """

  alias XIAM.Auth.UserPasskey
  alias XIAM.Auth.WebAuthn.Helpers
  alias XIAM.Auth.PasskeyRepository
  require Logger
  
  # Use configurable modules for testing support
  @wax_module Application.compile_env(:xiam, :wax_module, Wax)
  @helpers_module Application.compile_env(:xiam, :helpers_module, Helpers)

  @doc """
  Formats a UserPasskey struct into the map Wax expects for allow_credentials
  
  Uses the Base64URL encoded credential_id and attempts to decode it.
  """
  def format_credential_for_challenge(%UserPasskey{credential_id: b64_id}) do
    case Base.url_decode64(b64_id, padding: false) do
      {:ok, raw_id} ->
         %{type: "public-key", id: raw_id}
      :error ->
         Logger.error("Could not decode Base64 credential ID: #{b64_id} for challenge options.")
         nil # Cannot use this credential
    end
  end

  @doc """
  Gets credentials allowed for authentication based on email hint.
  
  If email is nil, returns an empty list which allows any credential with the RP ID.
  If email is provided, fetches all user's passkeys and formats them for authentication.
  
  ## Returns
  - List of formatted credentials (may be empty)
  """
  def get_allowed_credentials(nil) do
    Logger.debug("Generating usernameless authentication challenge.")
    [] # Empty list allows any credential associated with the RP ID
  end

  def get_allowed_credentials(email) when is_binary(email) do
    Logger.debug("Generating authentication challenge for user: #{email}")
    
    with {:ok, user} <- PasskeyRepository.get_user_by_email(email),
         passkeys <- PasskeyRepository.get_user_passkeys(user) do
      passkeys
      |> Enum.map(&format_credential_for_challenge/1)
      |> Enum.reject(&is_nil(&1)) # Filter out nil results from formatting
    else
      {:error, :user_not_found} ->
        Logger.warning("User not found for email: #{email} during auth option generation.")
        []
    end
  end

  @doc """
  Decodes an assertion map from the client into a standardized format
  used for WebAuthn verification.
  """
  def decode_assertion(%{"id" => credential_id_b64, "rawId" => raw_credential_id_b64, "response" => response, "type" => "public-key"}) when is_map(response) do
    try do
      # Prefer rawId if available (base64 encoded), fall back to id (base64 encoded)
      encoded_id_to_use = raw_credential_id_b64 || credential_id_b64
      credential_id_binary = Base.url_decode64!(encoded_id_to_use, padding: false)

      %{
        "authenticatorData" => authenticator_data_b64,
        "clientDataJSON" => client_data_json_b64,
        "signature" => signature_b64,
        "userHandle" => user_handle_b64 # May be nil in some flows
      } = response

      authenticator_data = Base.url_decode64!(authenticator_data_b64, padding: false)
      client_data_json = Base.url_decode64!(client_data_json_b64, padding: false)
      signature = Base.url_decode64!(signature_b64, padding: false)
      user_handle = if user_handle_b64, do: Base.url_decode64!(user_handle_b64, padding: false), else: nil

      Logger.debug("Decoded assertion successfully. Credential ID (base64): #{encoded_id_to_use}")

      {:ok, %{
        credential_id_b64: encoded_id_to_use, # Keep base64 id for lookup
        credential_id_binary: credential_id_binary, # Use binary id for Wax
        authenticator_data: authenticator_data,
        client_data_json: client_data_json,
        signature: signature,
        user_handle: user_handle
      }}
    rescue
      e ->
        unless Mix.env() == :test do
          Logger.error("Error decoding assertion components: #{inspect(e)}")
        end
        {:error, "Invalid assertion format or encoding: #{inspect(e)}"}
    end
  end
  
  def decode_assertion(invalid_assertion) do
    unless Mix.env() == :test do
      Logger.warning("Received invalid assertion structure: #{inspect(invalid_assertion)}")
    end
    {:error, "Invalid assertion structure. Expected map with id, rawId, response, type."}
  end

  @doc """
  Fetches the UserPasskey and associated User based on the BASE64 encoded credential ID.
  
  ## Parameters
  - `credential_id_b64` - Base64-URL encoded credential ID
  
  ## Returns
  - `{:ok, passkey, user}` if found
  - `{:error, reason}` if not found or on error
  """
  def get_passkey_and_user(credential_id_b64) when is_binary(credential_id_b64) do
    PasskeyRepository.get_passkey_with_user(credential_id_b64)
  end

  @doc """
  Updates the sign count on the UserPasskey.
  
  ## Parameters
  - `passkey` - UserPasskey struct to update
  - `new_sign_count` - New sign count value
  
  ## Returns
  - `{:ok, updated_passkey}` on success
  - `{:error, changeset}` on validation error
  """
  def update_passkey_sign_count(passkey, new_sign_count) do
    PasskeyRepository.update_sign_count(passkey, new_sign_count)
  end

  @doc """
  Verifies the WebAuthn assertion using Wax.
  
  ## Parameters
  - credential_info - Map containing the decoded credential information
  - passkey - The UserPasskey struct from the database
  - challenge - The Wax.Challenge struct
  
  ## Returns
  - {:ok, result} on successful verification
  - {:error, reason} on verification failure
  """
  def verify_with_wax(credential_info, passkey, challenge) do
    # Decode the stored public key from CBOR binary to a map for Wax
    # Use the configurable helpers module for easier testing
    public_key_map = @helpers_module.decode_public_key(passkey.public_key)

    @wax_module.authenticate(
      credential_info.authenticator_data,
      credential_info.client_data_json,
      credential_info.signature,
      public_key_map, # Pass the decoded map
      challenge,
      previous_sign_count: passkey.sign_count,
      user_handle: credential_info.user_handle
    )
  end
end
