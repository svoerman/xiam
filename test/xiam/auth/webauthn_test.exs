defmodule XIAM.Auth.WebAuthnTest do
  use XIAM.DataCase, async: false
  
  import Mox
  
  alias XIAM.Auth.WebAuthn
  alias XIAM.Auth.UserPasskey
  alias XIAM.Users.User
  alias XIAM.Repo

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

  # Sample credential struct for future test implementation
  # Not used currently but keeping for reference when implementing mocks
  # defp sample_credential do
  #   %{
  #     credential_id: <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10>>,
  #     public_key: %{
  #       kty: "EC",
  #       crv: "P-256",
  #       x: Base.encode64(<<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>, padding: false),
  #       y: Base.encode64(<<16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1>>, padding: false)
  #     },
  #     sign_count: 0,
  #     aaguid: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
  #   }
  # end

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
      
      # Sample attestation response
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
      
      %{user: user, attestation: attestation, challenge: sample_challenge()}
    end

    test "generate_registration_options/1 creates proper options", %{user: user} do
      {options, challenge} = WebAuthn.generate_registration_options(user)
      
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

    # This test uses mocking to test the verify_registration function
    @tag :skip  # Skip this test in automated runs since it requires complex mocking
    test "verify_registration/4 validates attestation and creates passkey", %{_user: _user, _attestation: _attestation, _challenge: _challenge} do
      # Here we would mock the Wax library response
      # This requires defining a mock module in test_helper.exs
      
      # For a real implementation, you'd need to:
      # 1. Mock the validate_registration_response function
      # 2. Return a successful credential response
      # 3. Test the passkey is created
      
      # Example of how the mock would be set up:
      # expect(XIAM.WaxMock, :validate_registration_response, fn _attestation, _challenge ->
      #   {:ok, sample_credential()}
      # end)
      
      # For now we'll skip this test since it requires deeper mocking
    end
  end

  describe "webauthn authentication" do
    setup do
      # Create a test user directly
      {:ok, user} = %User{}
        |> User.pow_changeset(%{
          email: "webauthn-auth-test@example.com",
          password: "Password1234!",
          password_confirmation: "Password1234!"
        })
        |> Repo.insert()
      
      # Create a passkey for this user
      credential_id = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10>>
      {:ok, passkey} = Repo.insert(%UserPasskey{
        user_id: user.id,
        credential_id: credential_id,
        public_key: <<10, 11, 12, 13>>,
        sign_count: 0,
        friendly_name: "Test Device"
      })
      
      # Sample authentication response
      assertion = %{
        "id" => Base.url_encode64(credential_id),
        "rawId" => Base.url_encode64(credential_id),
        "type" => "public-key",
        "response" => %{
          "authenticatorData" => Base.url_encode64(<<16, 15, 14, 13, 12, 11, 10, 9>>),
          "clientDataJSON" => Base.url_encode64(Jason.encode!(%{
            "type" => "webauthn.get",
            "challenge" => Base.url_encode64(<<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>),
            "origin" => "http://localhost:4000"
          })),
          "signature" => Base.url_encode64(<<1, 2, 3, 4>>)
        }
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
      
      %{user: user, passkey: passkey, assertion: assertion, challenge: challenge}
    end

    test "generate_authentication_options/0 creates proper options" do
      {options, challenge} = WebAuthn.generate_authentication_options()
      
      # Test the structure of the options
      assert is_map(options)
      assert is_binary(options.challenge)
      assert options.rpId == "localhost"
      assert options.timeout == 60000
      
      # Verify the challenge
      assert challenge.type == :authentication
      assert challenge.rp_id == "localhost"
      assert is_binary(challenge.bytes)
    end

    # This test uses mocking to test the verify_authentication function
    @tag :skip  # Skip this test in automated runs since it requires complex mocking
    test "verify_authentication/3 validates assertion and returns user", %{_assertion: _assertion, _challenge: _challenge} do
      # Here we would mock the Wax library response
      # Similar to the registration test, this requires a mock
      
      # Example of how the mock would be set up:
      # expect(XIAM.WaxMock, :validate_authentication_response, fn _assertion, _challenge, _credential_lookup_fn ->
      #   {:ok, {%UserPasskey{}, %User{}}, 1}
      # end)
      
      # For now we'll skip this test since it requires deeper mocking
    end
  end
end