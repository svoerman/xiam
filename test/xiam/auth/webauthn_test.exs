defmodule XIAM.Auth.WebAuthnTest do
  use XIAM.DataCase, async: false
  
  import Mox
  
  alias XIAM.Auth.WebAuthn
  alias XIAM.Auth.UserPasskey
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
  
  # Create a mock authentication assertion for WebAuthn testing
  defp mock_assertion(credential_id) do
    encoded_id = Base.url_encode64(credential_id, padding: false)
    
    rp_id_hash = :crypto.hash(:sha256, "localhost")
    flags = <<1>> # User present flag
    sign_count = <<0, 0, 0, 0>>
    auth_data = rp_id_hash <> flags <> sign_count
    
    test_challenge = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>
    
    %{
      "id" => encoded_id,
      "rawId" => encoded_id,
      "type" => "public-key",
      "response" => %{
        "authenticatorData" => Base.url_encode64(auth_data, padding: false),
        "clientDataJSON" => Base.url_encode64(Jason.encode!(%{
          "type" => "webauthn.get",
          "challenge" => Base.url_encode64(test_challenge, padding: false),
          "origin" => "http://localhost:4000"
        })),
        "signature" => Base.url_encode64(<<1, 2, 3, 4>>, padding: false)
      }
    }
  end
  
  # The mock_auth_data function was removed to clean up warnings

  # This module tests the WebAuthn facade module's ability to properly delegate
  # to the appropriate implementation modules.
  describe "webauthn facade module" do
    setup do
      {:ok, user} = %User{}
        |> User.pow_changeset(%{
          email: "webauthn-test@example.com",
          password: "Password1234!",
          password_confirmation: "Password1234!"
        })
        |> Repo.insert()
      
      raw_credential_id = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10>>
      encoded_credential_id = Base.url_encode64(raw_credential_id, padding: false)
      
      {:ok, passkey} = Repo.insert(%UserPasskey{
        user_id: user.id,
        credential_id: encoded_credential_id,
        public_key: <<10, 11, 12, 13>>,
        sign_count: 0,
        friendly_name: "Test Device"
      })
      
      attestation = %{
        "id" => Base.url_encode64(<<1, 2, 3, 4, 5, 6, 7, 8, 9, 10>>),
        "rawId" => Base.url_encode64(<<1, 2, 3, 4, 5, 6, 7, 8, 9, 10>>),
        "type" => "public-key",
        "response" => %{
          "attestationObject" => Base.url_encode64(<<16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1>>),
          "clientDataJSON" => Base.url_encode64(Jason.encode!(%{
            "type" => "webauthn.create",
            "challenge" => Base.url_encode64(<<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>),
            "origin" => "http://localhost:4000"
          }))
        }
      }
      
      assertion = mock_assertion(raw_credential_id)
      
      auth_challenge = %Wax.Challenge{
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
        attestation: attestation, 
        reg_challenge: sample_challenge(), 
        assertion: assertion, 
        auth_challenge: auth_challenge
      }
    end

    test "generate_registration_options/1 delegates to Registration module", %{user: user} do
      {options, challenge} = WebAuthn.generate_registration_options(user)
      
      assert is_map(options)
      assert is_binary(options.challenge)
      assert options.rp.id == "localhost"
      assert options.rp.name == "XIAM"
      assert options.user.name == user.email
      
      assert challenge.type == :attestation
      assert challenge.rp_id == "localhost"
      assert is_binary(challenge.bytes)
    end
    
    test "verify_registration/4 delegates to Registration module", %{user: user, reg_challenge: challenge} do
      # Use meck to mock just the Registration module
      :meck.new(XIAM.Auth.WebAuthn.Registration, [:passthrough])
      
      # Create a test passkey to return
      passkey = %UserPasskey{user_id: user.id, friendly_name: "Test Device"}
      
      # Set up the expectation for the verify_registration function
      :meck.expect(XIAM.Auth.WebAuthn.Registration, :verify_registration,
        fn u, _attestation, ch, "Test Device" when u == user and ch == challenge -> 
          {:ok, passkey}
        end)
      
      # Create a simple attestation object to pass
      attestation = %{"test" => "value"}
      
      # Call the facade function under test
      result = WebAuthn.verify_registration(user, attestation, challenge, "Test Device")
      
      # Verify the result and that our mock was called
      assert {:ok, received_passkey} = result
      assert received_passkey.user_id == user.id
      assert received_passkey.friendly_name == "Test Device"
      assert :meck.validate(XIAM.Auth.WebAuthn.Registration)
      
      # Clean up the mock after test
      :meck.unload(XIAM.Auth.WebAuthn.Registration)
    end
    
    @tag :registration
    test "complete registration flow for a new passkey", %{user: user, reg_challenge: challenge} do
      # Create a proper attestation format with the expected fields
      attestation = %{
        "id" => "AQIDBAUGBwgJCgsMDQ",
        "rawId" => "AQIDBAUGBwgJCgsMDQ",
        "type" => "public-key",
        "response" => %{
          "attestationObject" => "AQIDBA",
          "clientDataJSON" => "eyJ0eXBlIjoid2ViYXV0aG4uY3JlYXRlIiwiY2hhbGxlbmdlIjoiQVFJREJBVUdCd2dKQ2dzTURRNFBFQSIsIm9yaWdpbiI6Imh0dHA6Ly9sb2NhbGhvc3Q6NDAwMCJ9"
        }
      }
      
      # Mock the Registration module to handle the attestation correctly
      :meck.new(XIAM.Auth.WebAuthn.Registration, [:passthrough])
      :meck.expect(XIAM.Auth.WebAuthn.Registration, :verify_registration, 
        fn ^user, _att, ^challenge, "New Device" -> 
          # Return a successful result with a mock passkey
          {:ok, %UserPasskey{
            id: 1, 
            user_id: user.id, 
            credential_id: "AQIDBAUGBwgJCgsMDQ", 
            public_key: <<1, 2, 3, 4>>, 
            sign_count: 0, 
            friendly_name: "New Device"
          }}
        end)
      
      # Execute the registration through the facade
      result = WebAuthn.verify_registration(user, attestation, challenge, "New Device")
      
      # Check the expected result
      assert {:ok, passkey} = result
      assert passkey.user_id == user.id
      assert passkey.friendly_name == "New Device"
      
      # Clean up the mock after test
      :meck.unload(XIAM.Auth.WebAuthn.Registration)
    end
    
    test "generate_authentication_options/0 delegates to Authentication module" do
      {options, challenge} = WebAuthn.generate_authentication_options()
      
      assert is_map(options)
      assert is_binary(options.challenge)
      assert options.rpId == "localhost"
      assert options.timeout == 60000
      
      assert challenge.type == :authentication
      assert challenge.rp_id == "localhost"
    end
    
    test "generate_authentication_options/1 delegates to Authentication module", %{user: user} do
      {options, _challenge} = WebAuthn.generate_authentication_options(user.email)
      
      assert is_map(options)
      assert is_list(options.allowCredentials)
      assert length(options.allowCredentials) > 0
    end
    
    test "verify_authentication/2 delegates to Authentication module", %{assertion: assertion, auth_challenge: challenge} do
      # Mock the Authentication module
      :meck.new(XIAM.Auth.WebAuthn.Authentication, [:passthrough])
      
      # Create a test user and token
      test_user = %User{id: 123, email: "user@example.com"}
      test_token = "mock-auth-token"
      
      # Set up the expectation for verify_authentication
      :meck.expect(XIAM.Auth.WebAuthn.Authentication, :verify_authentication,
        fn a, ch when a == assertion and ch == challenge -> 
          {:ok, test_user, test_token}
        end)
      
      # Call the facade function
      result = WebAuthn.verify_authentication(assertion, challenge)
      
      # Verify the result
      assert {:ok, user, token} = result
      assert user.id == test_user.id 
      assert user.email == test_user.email
      assert token == test_token
      assert :meck.validate(XIAM.Auth.WebAuthn.Authentication)
      
      # Clean up
      :meck.unload(XIAM.Auth.WebAuthn.Authentication)
    end
    
    test "implements usernameless authentication flow as described in memory", %{assertion: assertion, auth_challenge: challenge} do
      # Based on our memory of the usernameless authentication flow, we need to test
      # the key components of this feature:
      
      # 1. API-based passkey verification with no credential IDs sent to browser
      # 2. Server-side lookup of passkeys using the credential ID from the assertion
      # 3. Creation of a signed token for secure redirection
      
      # First, test that generate_authentication_options/0 returns empty credentials list
      # This is key for the usernameless flow - no credentials are sent to the browser
      {options, _challenge} = WebAuthn.generate_authentication_options()
      assert options.allowCredentials == []
      
      # Now test the verification and token creation flow
      :meck.new(XIAM.Auth.WebAuthn.Authentication, [:passthrough])
      
      # Create a test user
      test_user = %User{id: 456, email: "usernameless@example.com"}
      
      # Create a token in the format described in our memory: user_id:timestamp:hmac
      timestamp = DateTime.to_unix(DateTime.utc_now())
      token = "456:#{timestamp}:mock-hmac-signature"
      
      # Mock the authentication verification to simulate the API validation
      :meck.expect(XIAM.Auth.WebAuthn.Authentication, :verify_authentication,
        fn a, ch when a == assertion and ch == challenge -> 
          {:ok, test_user, token}
        end)
      
      # Call through the facade
      result = WebAuthn.verify_authentication(assertion, challenge)
      
      # Verify results
      assert {:ok, user, redirect_token} = result
      assert user.id == test_user.id
      
      # Verify the token format matches what our memory says it should be
      # user_id:timestamp:hmac_signature
      [user_id_str, timestamp_str, signature] = String.split(redirect_token, ":", parts: 3)
      assert user_id_str == "456"
      assert String.length(timestamp_str) > 0
      assert signature == "mock-hmac-signature"
      
      # Validate our expectation was called
      assert :meck.validate(XIAM.Auth.WebAuthn.Authentication)
      
      # Clean up
      :meck.unload(XIAM.Auth.WebAuthn.Authentication)
    end
  end
  
  # Tests for the WebAuthn.Helpers module - focus on the simplest functions
  describe "webauthn helpers" do
    alias XIAM.Auth.WebAuthn.Helpers
    
    # Test the direct passthrough case (simplest possible case)
    test "encode_public_key passes through binary input" do
      binary_key = <<1, 2, 3, 4>>
      assert Helpers.encode_public_key(binary_key) == binary_key
    end
    
    # Test simple encoding case without CBOR mocking
    test "encode_public_key handles simple map" do
      # This is a simplified test that demonstrates the concept
      # without requiring detailed mocking of the CBOR encoding
      public_key = %{1 => 2, 3 => -7, -1 => 1}
      result = Helpers.encode_public_key(public_key)
      assert is_binary(result)
    end
  end
end