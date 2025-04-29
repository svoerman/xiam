defmodule XIAM.Auth.WebAuthn.CredentialExtractor do
  @moduledoc """
  Extracts WebAuthn credential information from attestation objects.
  
  This module handles the complex parsing logic for WebAuthn credentials,
  particularly for manual extraction when Wax library doesn't provide
  all necessary information.
  """
  
  require Logger
  
  @doc """
  Extracts credential information from attestation CBOR and client data hash.
  Used as a fallback when Wax.register/3 returns {:ok, {nil, _}} for 'none' attestations.
  
  ## Parameters
  - `attestation_cbor` - The parsed CBOR attestation object
  - `client_data_hash` - Hash of the client data JSON
  
  ## Returns
  - `{:ok, credential_info}` on success
  - `{:error, reason}` on failure
  """
  def extract_from_attestation({:ok, attestation_cbor, _}, _client_data_hash) do
    try do
      with %{"fmt" => "none", "authData" => auth_data} <- attestation_cbor,
           {:ok, auth_data_parsed} <- parse_auth_data(auth_data),
           true <- auth_data_parsed.attested_credential_data? do
        
        Logger.debug("Manual extraction successful for 'none' attestation.")
        {:ok, %{
          credential_id: auth_data_parsed.credential_id,
          public_key: auth_data_parsed.public_key_cbor,
          aaguid: auth_data_parsed.aaguid,
          sign_count: auth_data_parsed.sign_count
        }}
      else
        %{"fmt" => fmt} when fmt != "none" ->
          {:error, "Unsupported attestation format for manual extraction: #{fmt}"}
          
        false -> # attested_credential_data? is false
          {:error, "Auth data does not contain attested credential data"}
          
        error ->
          Logger.error("Manual extraction failed: #{inspect(error)}")
          {:error, "Failed to extract credential: invalid format"}
      end
    rescue
      e ->
        Logger.error("Error during credential extraction: #{inspect(e)}")
        {:error, "Credential extraction error: #{inspect(e)}"}
    end
  end
  
  def extract_from_attestation(error, _client_data_hash) do
    Logger.error("Invalid attestation CBOR: #{inspect(error)}")
    {:error, "Invalid attestation format"}
  end
  
  @doc """
  Parses WebAuthn authenticator data into a structured map.
  
  ## Parameters
  - `auth_data` - Binary authenticator data from the WebAuthn response
  
  ## Returns
  - `{:ok, parsed_data}` with parsed auth data
  - `{:error, reason}` on parsing failure
  """
  def parse_auth_data(auth_data) when is_binary(auth_data) do
    try do
      <<rpid_hash::binary-size(32), flags::binary-size(1), sign_count_bin::binary-size(4), rest::binary>> = auth_data
      
      # Parse flags
      <<user_present::1, user_verified::1, _reserved::3, attested_credential_data::1, extension_data::1, _::1>> = flags
      
      # Parse sign count
      <<sign_count::unsigned-integer-32>> = sign_count_bin
      
      result = %{
        rpid_hash: rpid_hash,
        user_present?: user_present == 1,
        user_verified?: user_verified == 1,
        attested_credential_data?: attested_credential_data == 1,
        extension_data?: extension_data == 1,
        sign_count: sign_count
      }
      
      # If we have attested credential data, parse it
      result = if attested_credential_data == 1 and byte_size(rest) > 0 do
        parse_attested_credential_data(result, rest)
      else
        result
      end
      
      {:ok, result}
    rescue
      e ->
        {:error, "Failed to parse auth data: #{inspect(e)}"}
    end
  end
  
  defp parse_attested_credential_data(result, data) do
    case data do
      <<aaguid::binary-size(16), id_len::unsigned-integer-16, rest::binary>> ->
        case rest do
          <<credential_id::binary-size(id_len), public_key_cbor::binary>> ->
            Map.merge(result, %{
              aaguid: aaguid,
              credential_id: credential_id,
              public_key_cbor: public_key_cbor
            })
          _ ->
            Map.put(result, :error, "Incomplete credential data")
        end
      _ ->
        Map.put(result, :error, "Invalid attested credential data format")
    end
  end
end
