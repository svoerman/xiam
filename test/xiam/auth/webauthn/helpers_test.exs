defmodule XIAM.Auth.WebAuthn.HelpersTest do
  use XIAM.DataCase, async: false
  
  import Mox
  
  alias XIAM.Auth.WebAuthn.Helpers
  
  # Mock implementation setup
  setup :verify_on_exit!

  describe "webauthn helpers" do
    # Test simple encoding case without CBOR mocking
    test "encode_public_key handles simple map" do
      # This is a simplified test that demonstrates the concept
      # without requiring detailed mocking of the CBOR encoding
      public_key = %{1 => 2, 3 => -7, -1 => 1}
      result = Helpers.encode_public_key(public_key)
      assert is_binary(result)
    end
    
    test "encode_user_id formats integer as binary" do
      user_id = 12345
      result = Helpers.encode_user_id(user_id)
      assert is_binary(result)
      assert byte_size(result) == 8 # 64-bit unsigned integer
    end
    
    test "decode_json_input handles both JSON strings and maps" do
      # Test with a map
      map_input = %{"key" => "value"}
      assert {:ok, map_input} == Helpers.decode_json_input(map_input)
      
      # Test with a JSON string
      json_input = Jason.encode!(map_input)
      assert {:ok, map_input} == Helpers.decode_json_input(json_input)
      
      # Test with invalid JSON
      assert {:error, _} = Helpers.decode_json_input("not valid json")
      
      # Test with nil
      assert {:error, _} = Helpers.decode_json_input(nil)
    end
  end
end
