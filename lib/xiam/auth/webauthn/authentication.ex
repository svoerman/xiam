defmodule XIAM.Auth.WebAuthn.Authentication do
  @moduledoc """
  Handles WebAuthn (passkey) authentication operations.
  """

  alias XIAM.Users.User
  alias XIAM.Auth.UserPasskey
  alias XIAM.Auth.WebAuthn.Helpers
  alias XIAM.Repo
  import Ecto.Query
  require Logger

  # Use compile_env for configuration fetched at compile time
  @rp_id Application.compile_env(:xiam, :webauthn, [])[:rp_id] || "localhost"

  @doc """
  Generates authentication options (challenge) for verifying a passkey.

  Can be called with or without an email hint.
  If email is provided, it tries to scope credentials to that user.
  If no email (usernameless), it allows any credential associated with the RP ID.

  ## Parameters
  - `email` (optional): The email address of the user attempting authentication.

  ## Returns
  - `{options, challenge}` tuple
  """
  def generate_authentication_options(email \\ nil) do
    allow_credentials = get_allowed_credentials(email)

    challenge = Wax.new_authentication_challenge(
      rp_id: @rp_id,
      allow_credentials: allow_credentials,
      user_verification: "preferred"
    )

    options = %{
      challenge: Base.url_encode64(challenge.bytes, padding: false),
      rpId: challenge.rp_id,
      allowCredentials: Enum.map(challenge.allow_credentials, fn cred ->
        %{ type: cred.type, id: Base.url_encode64(cred.id, padding: false) }
      end),
      userVerification: challenge.user_verification,
      timeout: challenge.timeout
    }

    {options, challenge}
  end

  @doc """
  Verifies an authentication assertion.

  Handles both standard authentication and usernameless authentication flows.

  ## Parameters
  - `assertion`: The assertion response from the client (as map or JSON string)
  - `challenge`: The challenge sent to the client during option generation

  ## Returns
  - `{:ok, user, passkey}` if authentication is successful
  - `{:error, reason}` if authentication fails
  """
  def verify_authentication(assertion, challenge) do
    case Helpers.decode_json_input(assertion) do
      {:ok, decoded_assertion} ->
        do_verify_authentication(decoded_assertion, challenge)
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_verify_authentication(assertion_map, challenge) when is_map(assertion_map) do
    case decode_assertion(assertion_map) do
      {:ok, credential_info} ->
        verify_and_update(credential_info, challenge)
      {:error, reason} ->
        unless Mix.env() == :test do
          Logger.error("Assertion decoding failed: #{inspect(reason)}")
        end
        {:error, reason}
    end
  end

  # --- Private Helpers --- #

  # Fetches allowed credentials based on email hint
  defp get_allowed_credentials(nil) do
    Logger.debug("Generating usernameless authentication challenge.")
    [] # Empty list allows any credential associated with the RP ID
  end

  defp get_allowed_credentials(email) when is_binary(email) do
    Logger.debug("Generating authentication challenge for user: #{email}")
    case Repo.get_by(User, email: email) do
      %User{} = user ->
        # Fetch passkeys associated with this user
        user
        |> Ecto.assoc(:passkeys)
        |> Repo.all()
        |> Enum.map(&format_credential_for_challenge/1)
        |> Enum.reject(&is_nil(&1)) # Filter out nil results from formatting

      nil ->
        Logger.warning("User not found for email: #{email} during auth option generation.") # Use Logger.warning
        [] # User not found, return empty list
    end
  end

  # Format a UserPasskey struct into the map Wax expects for allow_credentials
  # Use the Base64URL encoded credential_id and attempt to decode it.
  defp format_credential_for_challenge(%UserPasskey{credential_id: b64_id}) do
    case Base.url_decode64(b64_id, padding: false) do
      {:ok, raw_id} ->
         %{type: "public-key", id: raw_id} # Removed transports
      :error ->
         Logger.error("Could not decode Base64 credential ID: #{b64_id} for challenge options.")
         nil # Cannot use this credential
    end
  end

  # Decodes the assertion map from the client
  defp decode_assertion(%{"id" => credential_id_b64, "rawId" => raw_credential_id_b64, "response" => response, "type" => "public-key"}) when is_map(response) do
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
  defp decode_assertion(invalid_assertion) do
    unless Mix.env() == :test do
      Logger.warning("Received invalid assertion structure: #{inspect(invalid_assertion)}") # Use Logger.warning
    end
    {:error, "Invalid assertion structure. Expected map with id, rawId, response, type."}
  end


  # Verifies the decoded assertion against the challenge and updates the passkey
  defp verify_and_update(credential_info, challenge) do
    # Fetch based on the base64 encoded credential_id from the assertion
    with {:ok, passkey, user} <- get_passkey_and_user(credential_info.credential_id_b64),
         # Verify signature etc. using the binary credential ID
         {:ok, {auth_data, _signature}} <- do_wax_verify(credential_info, passkey, challenge),
         {:ok, updated_passkey} <- update_passkey_sign_count(passkey, auth_data.sign_count) # Update sign count
    do
      Logger.info("WebAuthn authentication successful for user ID: #{user.id}")
      {:ok, user, updated_passkey}
    else
      {:error, reason} ->
        Logger.warning("WebAuthn authentication failed: #{inspect(reason)}") # Use Logger.warning
        {:error, reason}

      e ->
        Logger.error("Unexpected error during WebAuthn verification: #{inspect(e)}")
        {:error, "Verification failed: #{inspect(e)}"}
    end
  end

  # Use Wax to verify the assertion components
  defp do_wax_verify(credential_info, passkey, challenge) do
     # Decode the stored public key from CBOR binary to a map for Wax
     public_key_map = Helpers.decode_public_key(passkey.public_key)

     Wax.authenticate(
       credential_info.authenticator_data,
       credential_info.client_data_json,
       credential_info.signature,
       public_key_map, # Pass the decoded map
       challenge,
       previous_sign_count: passkey.sign_count,
       user_handle: credential_info.user_handle
     )
  end

  # Fetches the UserPasskey and associated User based on the BASE64 encoded credential ID
  defp get_passkey_and_user(credential_id_b64) when is_binary(credential_id_b64) do
    query =
      from pk in UserPasskey,
      where: pk.credential_id == ^credential_id_b64, # Query using the stored base64 ID
      join: u in assoc(pk, :user),
      preload: [user: u],
      limit: 1

    case Repo.one(query) do
      %UserPasskey{user: %User{} = user} = passkey ->
        {:ok, passkey, user}
      nil ->
        Logger.warning("Passkey not found for credential ID (base64): #{credential_id_b64}")
        {:error, :credential_not_found}
      _ ->
         Logger.error("Unexpected result fetching passkey for credential ID (base64): #{credential_id_b64}")
         {:error, :database_error}
    end
  end

  # Updates the sign count on the UserPasskey
  defp update_passkey_sign_count(passkey, new_sign_count) do
    passkey
    |> UserPasskey.changeset(%{sign_count: new_sign_count})
    |> Repo.update()
  end

end
