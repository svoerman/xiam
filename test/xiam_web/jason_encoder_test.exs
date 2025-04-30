defmodule XIAMWeb.JasonEncoderTest do
  use ExUnit.Case, async: true

  # Test the Jason.Encoder implementation for Wax.Challenge
  test "verify Jason.Encoder protocol implementation for Wax.Challenge" do
    # Create a real Wax.Challenge struct
    challenge = %Wax.Challenge{
      bytes: <<1, 2, 3, 4>>,
      rp_id: "example.com",
      origin: "https://example.com",
      timeout: 60_000,
      user_verification: "preferred",
      attestation: "none",
      allow_credentials: [%{id: "cred123", type: "public-key"}],
      type: "webauthn.get",
      issued_at: DateTime.utc_now()
    }
    
    # Test direct encoding of the struct
    result = Jason.encode!(challenge)
    decoded = Jason.decode!(result)
    
    # Verify the struct was encoded correctly
    assert decoded["bytes"] == Base.url_encode64(<<1, 2, 3, 4>>, padding: false)
    assert decoded["rp_id"] == "example.com"
    assert decoded["origin"] == "https://example.com"
    assert decoded["timeout"] == 60_000
    assert decoded["user_verification"] == "preferred"
    assert decoded["attestation"] == "none"
    assert is_list(decoded["allow_credentials"])
    
    # Verify all fields from the Map.from_struct call are present
    expected_keys = ["bytes", "rp_id", "origin", "timeout", "user_verification", "attestation", "allow_credentials"]
    actual_keys = Map.keys(decoded)
    
    # Verify we have exactly the expected fields (no more, no less)
    assert Enum.sort(expected_keys) == Enum.sort(actual_keys)
  end
  
  # Test handling of nil values in the Wax.Challenge struct
  test "verify handling of nil values in Wax.Challenge struct" do
    # Create a challenge with nil values
    challenge = %Wax.Challenge{
      bytes: <<1, 2, 3, 4>>,
      rp_id: "example.com",
      origin: nil,
      timeout: nil,
      user_verification: nil,
      attestation: nil,
      allow_credentials: nil,
      type: "webauthn.get",
      issued_at: DateTime.utc_now()
    }
    
    # Test encoding and decoding
    result = Jason.encode!(challenge)
    decoded = Jason.decode!(result)
    
    # Verify nil values are handled correctly
    assert decoded["bytes"] == Base.url_encode64(<<1, 2, 3, 4>>, padding: false)
    assert decoded["rp_id"] == "example.com"
    assert decoded["origin"] == nil
    assert decoded["timeout"] == nil
    assert decoded["user_verification"] == nil
    assert decoded["attestation"] == nil
    assert decoded["allow_credentials"] == nil
  end
  
  # Test encoding of complex nested structures in allow_credentials
  test "verify encoding of complex allow_credentials field" do
    # Create a challenge with complex allow_credentials
    challenge = %Wax.Challenge{
      bytes: <<1, 2, 3, 4>>,
      rp_id: "example.com",
      origin: "https://example.com",
      allow_credentials: [
        %{id: "cred123", type: "public-key", transports: ["usb", "nfc"]},
        %{id: "cred456", type: "public-key", transports: ["internal"]}
      ],
      type: "webauthn.get",
      issued_at: DateTime.utc_now()
    }
    
    # Test encoding and decoding
    result = Jason.encode!(challenge)
    decoded = Jason.decode!(result)
    
    # Verify the complex nested structure is preserved
    assert length(decoded["allow_credentials"]) == 2
    [first, second] = decoded["allow_credentials"]
    assert first["id"] == "cred123"
    assert first["type"] == "public-key"
    assert first["transports"] == ["usb", "nfc"]
    assert second["id"] == "cred456"
  end
end
