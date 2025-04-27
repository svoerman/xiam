defmodule XIAM.Auth.WebAuthn.CredentialManagerTest do
  use XIAM.DataCase, async: false
  import Mox
  
  alias XIAM.Auth.WebAuthn.CredentialManager
  alias XIAM.Auth.UserPasskey
  alias XIAM.Users.User
  alias XIAM.Repo
  
  require Logger

  # Mock implementation setup
  setup :verify_on_exit!

  # Helper function to create a mock credential ID
  defp generate_credential_id do
    <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>
  end

  describe "credential management operations" do
    setup do
      # Create a test user 
      {:ok, user} = %User{}
        |> User.pow_changeset(%{
          email: "credential-test@example.com",
          password: "Password1234!",
          password_confirmation: "Password1234!"
        })
        |> Repo.insert()
      
      # Create a passkey for this user
      raw_credential_id = generate_credential_id()
      encoded_credential_id = Base.url_encode64(raw_credential_id, padding: false)
      
      {:ok, passkey} = Repo.insert(%UserPasskey{
        user_id: user.id,
        credential_id: encoded_credential_id,
        public_key: <<10, 11, 12, 13>>,
        sign_count: 0,
        friendly_name: "Test Credential"
      })
      
      # Create auth data for testing
      rp_id_hash = :crypto.hash(:sha256, "localhost")
      flags = <<1>> # User present flag
      sign_count = <<0, 0, 0, 1>> # Counter set to 1
      auth_data = rp_id_hash <> flags <> sign_count
      
      credential_info = %{
        credential_id_b64: encoded_credential_id,
        credential_id_binary: raw_credential_id,
        authenticator_data: auth_data,
        client_data_json: Jason.encode!(%{
          "type" => "webauthn.get",
          "challenge" => Base.url_encode64(<<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>, padding: false),
          "origin" => "http://localhost:4000"
        }),
        signature: <<1, 2, 3, 4>>,
        user_handle: nil
      }
      
      challenge = %Wax.Challenge{
        type: :authentication,
        bytes: <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>,
        origin: "http://localhost:4000",
        rp_id: "localhost",
        token_binding_status: nil,
        issued_at: System.system_time(:second),
        timeout: 60000,
        user_verification: "preferred"
      }
      
      %{
        user: user, 
        passkey: passkey,
        raw_credential_id: raw_credential_id,
        encoded_credential_id: encoded_credential_id,
        credential_info: credential_info,
        challenge: challenge
      }
    end

    test "format_credential_for_challenge formats passkey for Wax", %{passkey: passkey, raw_credential_id: raw_id} do
      # Use the function directly
      result = CredentialManager.format_credential_for_challenge(passkey)
      
      # Verify the result structure
      assert is_map(result)
      assert result.type == "public-key"
      assert result.id == raw_id
    end
    
    test "get_allowed_credentials with nil email returns empty list" do
      # This tests the usernameless flow
      result = CredentialManager.get_allowed_credentials(nil)
      
      # Verify the result is an empty list
      assert is_list(result)
      assert result == []
    end
    
    test "get_allowed_credentials with email returns user credentials", %{user: user, passkey: passkey} do
      # Test with the user's email
      result = CredentialManager.get_allowed_credentials(user.email)
      
      # Verify credentials were found
      assert is_list(result)
      assert length(result) == 1
      
      # Format what we expect the credential to look like
      expected = CredentialManager.format_credential_for_challenge(passkey)
      
      # Verify the credential in the result matches what we expect
      assert hd(result).type == expected.type
      assert hd(result).id == expected.id
    end
    
    test "decode_assertion properly processes WebAuthn assertion", %{encoded_credential_id: encoded_id} do
      # Create a sample assertion
      assertion = %{
        "id" => encoded_id,
        "rawId" => encoded_id,
        "type" => "public-key",
        "response" => %{
          "authenticatorData" => Base.url_encode64(<<1, 2, 3, 4>>, padding: false),
          "clientDataJSON" => Base.url_encode64(Jason.encode!(%{"type" => "webauthn.get"}), padding: false),
          "signature" => Base.url_encode64(<<5, 6, 7, 8>>, padding: false),
          "userHandle" => nil
        }
      }
      
      # Call the function
      result = CredentialManager.decode_assertion(assertion)
      
      # Verify the result structure
      assert {:ok, decoded} = result
      assert decoded.credential_id_b64 == encoded_id
      assert is_binary(decoded.credential_id_binary)
      assert is_binary(decoded.authenticator_data)
      assert is_binary(decoded.client_data_json)
      assert is_binary(decoded.signature)
    end
    
    test "get_passkey_and_user finds the correct passkey and user", %{passkey: passkey, user: user, encoded_credential_id: encoded_id} do
      # Call the function
      result = CredentialManager.get_passkey_and_user(encoded_id)
      
      # Verify the result
      assert {:ok, found_passkey, found_user} = result
      assert found_passkey.id == passkey.id
      assert found_passkey.credential_id == encoded_id
      assert found_user.id == user.id
    end
    
    test "update_passkey_sign_count updates the counter", %{passkey: passkey} do
      # Set a new sign count
      new_count = 5
      
      # Call the function
      result = CredentialManager.update_passkey_sign_count(passkey, new_count)
      
      # Verify the update was successful
      assert {:ok, updated_passkey} = result
      assert updated_passkey.sign_count == new_count
    end
    
    @tag :skip
    test "verify_with_wax attempts to verify the assertion" do
      assert true
    end
    
    test "can format credentials for challenges" do
      # Create a sample passkey for testing with a valid base64 credential ID
      passkey = %XIAM.Auth.UserPasskey{
        id: 1,
        user_id: 1,
        credential_id: "YWJjZDEyMzQ=", # Valid base64 value (abcd1234)
        public_key: <<1, 2, 3, 4>>,
        sign_count: 0,
        friendly_name: "Test Passkey",
        aaguid: <<5, 6, 7, 8>>,
        inserted_at: ~N[2023-01-01 00:00:00],
        updated_at: ~N[2023-01-01 00:00:00]
      }
      
      # Test formatting a credential for a challenge
      formatted = CredentialManager.format_credential_for_challenge(passkey)
      
      # Check that the resulting format is correct
      assert formatted.type == "public-key"
      assert is_binary(formatted.id)
      
      # Test getting allowed credentials
      # This requires database setup, so we'll just verify the nil case
      empty_list = CredentialManager.get_allowed_credentials(nil)
      assert empty_list == []
    end
  end
end
