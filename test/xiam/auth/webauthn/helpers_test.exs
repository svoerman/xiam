defmodule XIAM.Auth.WebAuthn.HelpersTest do
  use XIAM.DataCase, async: false
  
  import Mox
  require Logger
  
  alias XIAM.Auth.WebAuthn.Helpers
  
  # Configure the logger to ignore CBOR decoding errors during test
  setup do
    # Store the original level
    original_level = Logger.level()
    
    # Temporarily increase log level to suppress specific WebAuthn error messages
    # during tests (error level is 2, critical is 0, setting to critical will suppress errors)
    Logger.configure(level: :critical)
    
    # Reset logger level after test
    on_exit(fn -> Logger.configure(level: original_level) end)
    
    :ok
  end
  
  # Mock implementation setup
  setup :verify_on_exit!

  describe "encode_public_key function" do
    test "handles simple map encoding to CBOR" do
      # Simple map for CBOR encoding
      public_key = %{1 => 2, 3 => -7, -1 => 1}
      result = Helpers.encode_public_key(public_key)
      assert is_binary(result)
    end
    
    test "returns binary unchanged when given binary input" do
      binary_input = <<1, 2, 3, 4>>
      assert binary_input == Helpers.encode_public_key(binary_input)
    end
    
    test "raises error for invalid input types" do
      # Only test with inputs that will actually raise an error
      # The implementation only raises for inputs that are neither maps nor binaries
      invalid_inputs = [nil, [1, 2, 3]]
      
      for input <- invalid_inputs do
        assert_raise RuntimeError, ~r/Invalid public key format/, fn ->
          Helpers.encode_public_key(input)
        end
      end
      
      # String is converted to charlist by CBOR.encode, so it won't raise
      # Integer might be handled by CBOR.encode as well
    end
  end
  
  describe "decode_public_key function" do
    test "successfully decodes valid CBOR binary to map" do
      # Create a simple map and encode it to CBOR
      original_map = %{1 => 2, 3 => 4}
      cbor_binary = CBOR.encode(original_map)
      
      # Decode it back
      result = Helpers.decode_public_key(cbor_binary)
      assert is_map(result)
      assert result == original_map
    end
    
    test "raises error for invalid CBOR binary" do
      invalid_cbor = <<0, 1, 2, 3>> # Not valid CBOR
      
      # Temporarily capture and silence log output during this test
      ExUnit.CaptureLog.capture_log(fn ->
        assert_raise RuntimeError, ~r/Failed to decode public key CBOR/, fn ->
          Helpers.decode_public_key(invalid_cbor)
        end
      end)
    end
    
    test "raises error for non-binary input" do
      invalid_inputs = [nil, 123, %{}, [1, 2, 3]]
      
      for input <- invalid_inputs do
        assert_raise RuntimeError, ~r/Invalid public key format/, fn ->
          Helpers.decode_public_key(input)
        end
      end
    end
  end
  
  describe "encode_user_id function" do
    test "formats integer as 64-bit binary" do
      # Test with different integer values
      test_cases = [
        {0, <<0, 0, 0, 0, 0, 0, 0, 0>>},
        {1, <<0, 0, 0, 0, 0, 0, 0, 1>>},
        {12345, <<0, 0, 0, 0, 0, 0, 48, 57>>},
        {0xFFFFFFFF, <<0, 0, 0, 0, 255, 255, 255, 255>>} # Max 32-bit value
      ]
      
      for {input, expected} <- test_cases do
        result = Helpers.encode_user_id(input)
        assert result == expected
        assert byte_size(result) == 8 # 64-bit unsigned integer
      end
    end
  end
  
  describe "decode_json_input function" do
    test "handles valid JSON string input" do
      # Test with simple JSON object
      map_input = %{"key" => "value", "nested" => %{"a" => 1}}
      json_input = Jason.encode!(map_input)
      assert {:ok, map_input} == Helpers.decode_json_input(json_input)
    end
    
    test "handles map input by returning it unchanged" do
      map_input = %{"key" => "value"}
      assert {:ok, map_input} == Helpers.decode_json_input(map_input)
    end
    
    test "returns error for invalid JSON string" do
      invalid_json = "{key: value}" # Not valid JSON
      {:error, message} = Helpers.decode_json_input(invalid_json)
      assert message =~ "Invalid JSON input"
    end
    
    test "returns error when JSON decodes to non-map value" do
      # JSON array, which decodes to a list not a map
      json_array = "[1, 2, 3]"
      {:error, message} = Helpers.decode_json_input(json_array)
      assert message =~ "Invalid input format: expected JSON object"
    end
    
    test "returns error for nil input" do
      {:error, message} = Helpers.decode_json_input(nil)
      assert message =~ "Invalid input type"
    end
    
    test "returns error for other data types" do
      invalid_inputs = [123, true, [1, 2, 3]]
      
      for input <- invalid_inputs do
        {:error, message} = Helpers.decode_json_input(input)
        assert message =~ "Invalid input type"
      end
    end
  end
end
