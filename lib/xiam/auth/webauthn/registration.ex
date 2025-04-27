defmodule XIAM.Auth.WebAuthn.Registration do
  @moduledoc """
  Handles WebAuthn (passkey) registration operations.
  """

  alias XIAM.Users.User
  alias XIAM.Auth.UserPasskey
  alias XIAM.Auth.WebAuthn.Helpers
  alias XIAM.Repo
  # import Ecto.Query  # Commented out as it's not being used
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
  def generate_registration_options(%User{} = user) do
    # Create a new registration challenge
    authenticator_selection = %{
      authenticator_attachment: "platform",
      resident_key: "preferred",
      user_verification: "preferred"
    }

    challenge = Wax.new_registration_challenge(
      rp_id: @rp_id,
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
    case Helpers.decode_json_input(attestation) do
      {:ok, decoded_attestation} ->
        do_verify_registration(user, decoded_attestation, challenge, friendly_name)
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_verify_registration(%User{} = user, attestation_map, challenge, friendly_name) when is_map(attestation_map) do
    try do
      # Process the attestation
      case process_registration(attestation_map, challenge) do
        {:ok, credential_info} ->
          # Create a new passkey
          %UserPasskey{}
          |> UserPasskey.changeset(%{
            user_id: user.id,
            # Store only the base64url encoded ID as per current schema
            credential_id: Base.url_encode64(credential_info.credential_id, padding: false),
            public_key: Helpers.encode_public_key(credential_info.public_key),
            sign_count: credential_info.sign_count,
            friendly_name: friendly_name,
            aaguid: credential_info.aaguid
            # Removed :raw_credential_id and :transports as they are not in the schema
          })
          |> Repo.insert()

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Registration verification error: #{inspect(e)}")
        {:error, "Registration failed: #{inspect(e)}"}
    end
  end

  # Process registration attestation using Wax
  # Handle direct format with top-level keys
  defp process_registration(%{"attestationObject" => attestation_object, "clientDataJSON" => client_data_json}, %Wax.Challenge{} = challenge) do
    try do
      decoded_attestation_obj = Base.url_decode64!(attestation_object, padding: false)
      decoded_client_data_json = Base.url_decode64!(client_data_json, padding: false)

      case Wax.register(decoded_attestation_obj, decoded_client_data_json, challenge) do
        {:ok, {%Wax.AuthenticatorData{attested_credential_data: cred_data, sign_count: sign_count}, _attestation_statement}} ->
          Logger.debug("Wax registration successful.")
          {:ok, %{
            credential_id: cred_data.credential_id,
            public_key: cred_data.credential_public_key,
            aaguid: cred_data.aaguid,
            sign_count: sign_count, # Use sign_count from AuthenticatorData
            # Removed :transports
          }}

        # Handle cases where Wax returns {:ok, {nil, _}}
        # This might happen with certain attestation types (e.g., 'none')
        # We might need manual extraction if Wax doesn't parse everything
        {:ok, {nil, _fmt}} ->
            Logger.warning("Wax.register returned nil credential data. Attempting manual extraction.", [])
           # If Wax doesn't provide the data directly, try manual parsing
           # (Note: This might be less reliable than Wax's parsing)
           parsed_attestation = CBOR.decode(decoded_attestation_obj)
           client_data_hash = :crypto.hash(:sha256, decoded_client_data_json)
           extract_credential_manually(parsed_attestation, client_data_hash)

        {:error, reason} ->
          Logger.error("Wax registration failed: #{inspect(reason)}")
          {:error, "Registration failed: #{inspect(reason)}"}
      end
    rescue
      e ->
        Logger.error("Error decoding/processing registration: #{inspect(e)} - Attestation: #{attestation_object}, ClientData: #{client_data_json}")
        {:error, "Registration processing error: #{inspect(e)}"}
    end
  end
  # Handle modern browser format with response nested key
  defp process_registration(%{"response" => %{"attestationObject" => attestation_object, "clientDataJSON" => client_data_json}, "type" => "public-key"}, %Wax.Challenge{} = challenge) do
    # Pass the nested values to the same processing logic
    process_registration(%{"attestationObject" => attestation_object, "clientDataJSON" => client_data_json}, challenge)
  end

  defp process_registration(_invalid_attestation, _challenge) do
     {:error, "Invalid attestation format. Expected map with 'attestationObject' and 'clientDataJSON'."}
  end

  # Helper function to manually extract credential info if Wax doesn't
  # Caution: This might be necessary for 'none' attestation but relies on CBOR structure.
  defp extract_credential_manually({:ok, attestation_cbor, _}, _client_data_hash) do
    try do
      with %{"fmt" => "none", "authData" => auth_data} <- attestation_cbor,
           <<_rpid_hash::binary-size(32), flags::binary-size(1), sign_count_bin::binary-size(4), rest_auth_data::binary>> <- auth_data,
           <<_::5, at_flag::1, _::2>> = flags, # Check Attested Credential Data included flag (AT)
           1 = at_flag, # Use pattern matching to ensure at_flag is 1
           <<aaguid::binary-size(16), id_len::unsigned-integer-16, cred_data_rest::binary>> <- rest_auth_data,
           <<credential_id::binary-size(id_len), public_key_cbor::binary>> <- cred_data_rest
      do
        <<sign_count::unsigned-integer-32>> = sign_count_bin
        # Attempt to decode public key to ensure it's valid CBOR
        case CBOR.decode(public_key_cbor) do
          {:ok, _public_key_map, _} ->

            Logger.debug("Manual extraction successful for 'none' attestation.")
            {:ok, %{
              credential_id: credential_id,
              public_key: public_key_cbor, # Store raw CBOR
              aaguid: aaguid,
              sign_count: sign_count
              # Removed :transports
            }}
          {:error, reason} ->
            Logger.error("Failed to decode public key CBOR: #{inspect(reason)}")
            {:error, "Invalid public key format: #{inspect(reason)}"}
        end
      else
        _ ->
          Logger.error("Manual extraction failed: Could not parse authData or missing attested data.")
          {:error, "Manual extraction failed: Invalid authData structure or missing attested data."}
      end
    rescue
      e ->
        Logger.error("Error during manual credential extraction: #{inspect(e)}")
        {:error, "Error extracting credential manually: #{inspect(e)}"}
    end
  end
  defp extract_credential_manually({:error, reason}, _) do
    Logger.error("Manual extraction failed: CBOR decoding error - #{inspect(reason)}")
    {:error, "Invalid attestation object CBOR: #{inspect(reason)}"}
  end
  defp extract_credential_manually(_, _) do
    {:error, "Manual extraction failed: Unexpected format."}
  end

end
