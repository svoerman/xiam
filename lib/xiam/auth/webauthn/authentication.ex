defmodule XIAM.Auth.WebAuthn.Authentication do
  @moduledoc """
  Handles WebAuthn (passkey) authentication operations.
  """

  alias XIAM.Auth.WebAuthn.Helpers
  alias XIAM.Auth.WebAuthn.CredentialManager
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
    allow_credentials = CredentialManager.get_allowed_credentials(email)

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
    case CredentialManager.decode_assertion(assertion_map) do
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

  # Verify and update is the main verification logic that uses the credential manager


  # Verifies the decoded assertion against the challenge and updates the passkey
  defp verify_and_update(credential_info, challenge) do
    # Fetch based on the base64 encoded credential_id from the assertion
    with {:ok, passkey, user} <- CredentialManager.get_passkey_and_user(credential_info.credential_id_b64),
         # Verify signature etc. using the binary credential ID
         {:ok, {auth_data, _signature}} <- CredentialManager.verify_with_wax(credential_info, passkey, challenge),
         {:ok, updated_passkey} <- CredentialManager.update_passkey_sign_count(passkey, auth_data.sign_count) # Update sign count
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
end
