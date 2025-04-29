defmodule XIAM.Auth.TokenValidatorTest do
  use XIAM.DataCase
  
  alias XIAM.Auth.TokenValidator
  alias XIAM.Auth.PasskeyTokenReplay
  
  setup do
    # Set the current time reference for tests
    current_time = :os.system_time(:second)
    {:ok, %{current_time: current_time}}
  end
  
  describe "create_token/1" do
    test "creates a valid token with correct format" do
      user_id = 42
      token = TokenValidator.create_token(user_id)
      
      assert is_binary(token)
      assert String.contains?(token, ":")
      
      # Token should have 3 parts
      parts = String.split(token, ":")
      assert length(parts) == 3
      
      # First part should be user_id
      assert String.to_integer(Enum.at(parts, 0)) == user_id
      
      # Second part should be a timestamp
      timestamp_str = Enum.at(parts, 1)
      {timestamp, _} = Integer.parse(timestamp_str)
      assert is_integer(timestamp)
      
      # Third part should be a base64 encoded HMAC
      hmac = Enum.at(parts, 2)
      assert is_binary(hmac)
      assert String.length(hmac) > 0
    end
  end
  
  describe "validate_token/1" do
    setup do
      # Create a valid token for testing
      user_id = 42
      timestamp = :os.system_time(:second)
      hmac = generate_test_hmac("#{user_id}:#{timestamp}")
      token = "#{user_id}:#{timestamp}:#{hmac}"
      
      {:ok, %{token: token, user_id: user_id, timestamp: timestamp}}
    end
    
    test "validates a valid token", %{token: token, user_id: user_id, timestamp: timestamp} do
      # Stub the used? function to return false
      :meck.new(PasskeyTokenReplay, [:passthrough])
      :meck.expect(PasskeyTokenReplay, :used?, fn _, _ -> false end)
      
      try do
        assert {:ok, {^user_id, ^timestamp}} = TokenValidator.validate_token(token)
        assert :meck.called(PasskeyTokenReplay, :used?, [user_id, timestamp])
      after
        :meck.unload(PasskeyTokenReplay)
      end
    end
    
    test "returns error for expired token", %{token: _token} do
      # Create a token with expired timestamp
      user_id = 42
      expired_timestamp = :os.system_time(:second) - 600 # 10 minutes ago (beyond max age)
      hmac = generate_test_hmac("#{user_id}:#{expired_timestamp}")
      expired_token = "#{user_id}:#{expired_timestamp}:#{hmac}"
      
      assert {:error, :expired} = TokenValidator.validate_token(expired_token)
    end
    
    test "returns error for invalid signature", %{user_id: user_id, timestamp: timestamp} do
      # Create a token with invalid HMAC
      invalid_token = "#{user_id}:#{timestamp}:invalid_hmac"
      
      assert {:error, :invalid_signature} = TokenValidator.validate_token(invalid_token)
    end
    
    test "returns error for already used token", %{token: token, user_id: user_id, timestamp: timestamp} do
      # Stub the token as already used
      :meck.new(PasskeyTokenReplay, [:passthrough])
      :meck.expect(PasskeyTokenReplay, :used?, fn _, _ -> true end)
      
      try do
        assert {:error, :already_used} = TokenValidator.validate_token(token)
        assert :meck.called(PasskeyTokenReplay, :used?, [user_id, timestamp])
      after
        :meck.unload(PasskeyTokenReplay)
      end
    end
    
    test "returns error for invalid token format" do
      assert {:error, :invalid_token_format} = TokenValidator.validate_token("invalid_token")
      assert {:error, :invalid_token_format} = TokenValidator.validate_token("part1:part2")
      assert {:error, :invalid_token_format} = TokenValidator.validate_token("not_a_number:123:hmac")
    end
  end
  
  describe "mark_used/2" do
    test "marks a token as used" do
      user_id = 42
      timestamp = :os.system_time(:second)
      
      # Stub the mark_used function
      :meck.new(PasskeyTokenReplay, [:passthrough])
      :meck.expect(PasskeyTokenReplay, :mark_used, fn _, _ -> :ok end)
      
      try do
        assert :ok = TokenValidator.mark_used(user_id, timestamp)
        assert :meck.called(PasskeyTokenReplay, :mark_used, [user_id, timestamp])
      after
        :meck.unload(PasskeyTokenReplay)
      end
    end
  end
  
  # Helper functions
  
  defp generate_test_hmac(data) do
    # Use a test secret consistent with what TokenValidator should use
    secret = Application.get_env(:xiam, XIAMWeb.Endpoint)[:secret_key_base]
    :crypto.mac(:hmac, :sha256, secret, data)
      |> Base.url_encode64(padding: false)
  end
end
