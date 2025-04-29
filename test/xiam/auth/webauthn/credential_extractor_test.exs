defmodule XIAM.Auth.WebAuthn.CredentialExtractorTest do
  use XIAM.DataCase
  
  alias XIAM.Auth.WebAuthn.CredentialExtractor
  
  describe "extract_from_attestation/2" do
    test "extracts credential for valid 'none' attestation" do
      mock_attestation = {:ok, %{
        "fmt" => "none",
        "authData" => create_test_auth_data()
      }, ""}
      
      assert {:ok, credential_info} = CredentialExtractor.extract_from_attestation(mock_attestation, "")
      assert is_binary(credential_info.credential_id)
      assert is_binary(credential_info.public_key)
      assert is_binary(credential_info.aaguid)
      assert is_integer(credential_info.sign_count)
    end
    
    test "returns error for non-'none' attestation" do
      mock_attestation = {:ok, %{"fmt" => "packed", "authData" => "data"}, ""}
      
      assert {:error, _} = CredentialExtractor.extract_from_attestation(mock_attestation, "", suppress_log: true)
    end
    
    test "returns error for invalid format" do
      assert {:error, _} = CredentialExtractor.extract_from_attestation({:error, "reason"}, "", suppress_log: true)
    end
  end
  
  describe "parse_auth_data/1" do
    test "parses valid authenticator data" do
      auth_data = create_test_auth_data()
      
      assert {:ok, result} = CredentialExtractor.parse_auth_data(auth_data)
      assert result.attested_credential_data?
      assert is_binary(result.credential_id)
      assert is_binary(result.public_key_cbor)
    end
    
    test "returns error for invalid auth data" do
      assert {:error, _} = CredentialExtractor.parse_auth_data(<<1, 2, 3>>)
    end
  end
  
  # Helper to create test authenticator data with credential data
  defp create_test_auth_data do
    # Mock RP ID hash (32 bytes)
    rpid_hash = :crypto.strong_rand_bytes(32)
    
    # Create flags byte - bit 6 (attested credential data) set to 1
    flags = <<0::5, 1::1, 0::2>>
    
    # Set sign count to 1
    sign_count = <<1::unsigned-integer-32>>
    
    # Create test AAGUID (16 bytes)
    aaguid = :crypto.strong_rand_bytes(16)
    
    # Create credential ID length (2 bytes) and credential ID (16 bytes)
    cred_id_len = <<16::unsigned-integer-16>>
    cred_id = :crypto.strong_rand_bytes(16)
    
    # Create test public key in CBOR format
    # This is a very simplified CBOR map that should be decodable
    public_key_cbor = <<
      # CBOR map with 2 entries
      0xA2,
      # Key 1 (integer) 
      0x01,
      # Value 1 (integer)
      0x02,
      # Key 2 (integer)
      0x03,
      # Value 2 (integer)
      0x04
    >>
    
    # Combine all parts
    rpid_hash <> flags <> sign_count <> aaguid <> cred_id_len <> cred_id <> public_key_cbor
  end
end
