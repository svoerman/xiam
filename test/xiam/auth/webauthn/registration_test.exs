defmodule XIAM.Auth.WebAuthn.RegistrationTest do
  use XIAM.DataCase, async: false
  
  import Mock
  import Mox
  
  alias XIAM.Auth.WebAuthn.Registration
  alias XIAM.Users.User
  alias XIAM.Repo
  
  require Logger

  # Mock implementation setup
  setup :verify_on_exit!

  # Helper to create a sample challenge
  defp sample_challenge do
    %Wax.Challenge{
      type: :registration,
      bytes: <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>,
      origin: "http://localhost:4000",
      rp_id: "localhost",
      token_binding_status: nil,
      issued_at: System.system_time(:second),
      timeout: 60000,
      attestation: "none",
      user_verification: "preferred"
    }
  end

  describe "webauthn registration" do
    setup do
      # Create a test user directly
      {:ok, user} = %User{}
        |> User.pow_changeset(%{
          email: "webauthn-test@example.com",
          password: "Password1234!",
          password_confirmation: "Password1234!"
        })
        |> Repo.insert()
      
      # Sample attestation response correctly formatted for WebAuthn
      attestation = %{
        "id" => Base.url_encode64(<<1, 2, 3, 4, 5, 6, 7, 8, 9, 10>>, padding: false),
        "rawId" => Base.url_encode64(<<1, 2, 3, 4, 5, 6, 7, 8, 9, 10>>, padding: false),
        "type" => "public-key",
        "response" => %{
          "attestationObject" => Base.url_encode64(<<16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1>>, padding: false),
          "clientDataJSON" => Base.url_encode64(Jason.encode!(%{
            "type" => "webauthn.create",
            "challenge" => Base.url_encode64(<<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>, padding: false),
            "origin" => "http://localhost:4000"
          }), padding: false)
        }
      }
      
      %{user: user, attestation: attestation, challenge: sample_challenge()}
    end

    test "generate_registration_options/1 creates proper options", %{user: user} do
      {options, challenge} = Registration.generate_registration_options(user)
      
      # Test the structure of the options
      assert is_map(options)
      assert is_binary(options.challenge)
      assert options.rp.id == "localhost"
      assert options.rp.name == "XIAM"
      assert options.user.name == user.email
      assert options.user.id != nil
      
      # Verify the challenge 
      # Note: The implementation appears to use :attestation as the type instead of :registration
      assert challenge.type == :attestation
      assert challenge.rp_id == "localhost"
      assert is_binary(challenge.bytes)
    end

    # Test the verify_registration functionality with mocked dependencies
    test "verify_registration/4 creates a passkey with the right parameters", %{user: user, challenge: challenge} do
      # Let's focus on testing the key functionality - proper passkey creation
      # and attributes - by mocking at a higher level
      
      # Create an attestation that matches the exact structure expected by process_registration
      attestation = %{
        "attestationObject" => "AQIDBA",  # This is just a placeholder
        "clientDataJSON" => "eyJ0eXBlIjoid2ViYXV0aG4uY3JlYXRlIiwiY2hhbGxlbmdlIjoiQVFJREJBVUdCd2dKQ2dzTURRNFBFQSIsIm9yaWdpbiI6Imh0dHA6Ly9sb2NhbGhvc3Q6NDAwMCJ9"
      }
      
      # Create mocks for all the dependencies using the Mock library
      with_mocks([
        {XIAM.Auth.WebAuthn.Helpers, [],
          [
            decode_json_input: fn input -> {:ok, input} end,
            encode_public_key: fn input -> input end
          ]},
        
        {CBOR, [],
          [
            decode: fn _binary -> {:ok, %{"fmt" => "none", "authData" => <<1, 2, 3, 4>>}, <<>>} end
          ]},
        
        {Wax, [],
          [
            register: fn _attestation, _client_data, _challenge ->
              # Mock a successful registration result
              mock_auth_data = %{
                __struct__: Wax.AuthenticatorData,
                attested_credential_data: %{
                  __struct__: Wax.AttestedCredentialData,
                  credential_id: <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10>>,
                  aaguid: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
                  credential_public_key: <<1, 2, 3, 4>>
                },
                sign_count: 0
              }
              
              {:ok, {mock_auth_data, "none"}}
            end
          ]},
        
        # Bypass the actual UserPasskey validation
        # We need to use Bypass to avoid the schema validation while still returning a changeset
        {XIAM.Auth.UserPasskey, [],
          [
            changeset: fn _passkey, attrs ->
              # Create a valid changeset that doesn't validate the required fields
              # This allows us to test the controller without hitting actual database constraints
              cs = %Ecto.Changeset{
                valid?: true,
                changes: attrs,
                data: %XIAM.Auth.UserPasskey{
                  id: "test-id-123",
                  user_id: attrs[:user_id],
                  credential_id: attrs[:credential_id],
                  public_key: attrs[:public_key],
                  sign_count: attrs[:sign_count],
                  friendly_name: attrs[:friendly_name]
                },
                types: %{}
              }
              cs
            end
          ]},
        
        {XIAM.Repo, [],
          [
            insert: fn changeset ->
              # Return a passkey with the attributes from the changeset
              {:ok, Ecto.Changeset.apply_changes(changeset)}
            end
          ]}
      ]) do
      
      # Test registration verification and passkey creation
      result = Registration.verify_registration(user, attestation, challenge, "Test Device")
      
      # Verify we get a successful result with a passkey
      assert {:ok, passkey} = result
      
      # Verify passkey was created with correct attributes
      assert passkey.user_id == user.id
      assert passkey.friendly_name == "Test Device"
      end
    end
    
    test "verify_registration/4 handles invalid attestation format", %{user: user, challenge: challenge} do
      # Test with various invalid attestation formats
      invalid_attestations = [
        nil,
        "not-a-map",
        %{}, # Empty map
        %{"type" => "public-key"}, # Missing required fields
        %{"id" => "AQIDBAUGBwgJCg", "type" => "public-key"}, # Missing response
        %{"id" => "invalid-id", "type" => "public-key", "response" => %{}} # Invalid ID format
      ]
      
      # Each invalid attestation should result in an error
      Enum.each(invalid_attestations, fn invalid_attestation ->
        assert {:error, reason} = Registration.verify_registration(user, invalid_attestation, challenge, "Test Device")
        assert is_binary(reason)
      end)
    end
  end
end
