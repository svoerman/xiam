defmodule XIAM.Auth.TokenValidator do
  @moduledoc """
  Validates authentication tokens used in the passkey authentication flow.
  
  This module manages the token lifecycle (creation, validation, consumption)
  for securely transferring authentication state between API and web contexts.
  """
  
  alias XIAM.Auth.PasskeyTokenReplay
  require Logger
  
  @max_token_age 300 # 5 minutes in seconds
  
  @doc """
  Creates a signed authentication token for a user.
  
  ## Parameters
  - `user_id` - User ID to encode in the token
  
  ## Returns
  - Token in the format "user_id:timestamp:hmac"
  """
  def create_token(user_id) when is_integer(user_id) do
    timestamp = :os.system_time(:second)
    user_id_str = Integer.to_string(user_id)
    timestamp_str = Integer.to_string(timestamp)
    
    # Compute HMAC signature
    data = user_id_str <> ":" <> timestamp_str
    hmac = generate_hmac(data)
    
    # Create the token
    data <> ":" <> hmac
  end
  
  @doc """
  Validates a token and returns the user ID if valid.
  
  ## Parameters
  - `token` - Token to validate
  
  ## Returns
  - `{:ok, {user_id, timestamp}}` if token is valid
  - `{:error, reason}` if token is invalid or expired
  """
  def validate_token(token) when is_binary(token) do
    with {:ok, {user_id, timestamp, received_hmac}} <- decode_token(token),
         :ok <- verify_expiration(timestamp),
         :ok <- verify_signature(user_id, timestamp, received_hmac),
         :ok <- verify_not_used(user_id, timestamp) do
      {:ok, {user_id, timestamp}}
    end
  end
  
  @doc """
  Marks a token as used to prevent replay attacks.
  
  ## Parameters
  - `user_id` - User ID from the token
  - `timestamp` - Timestamp from the token
  
  ## Returns
  - `:ok`
  """
  def mark_used(user_id, timestamp) do
    PasskeyTokenReplay.mark_used(user_id, timestamp)
    :ok
  end
  
  # Private functions
  
  defp decode_token(token) do
    case String.split(token, ":", parts: 3) do
      [user_id_str, timestamp_str, hmac] ->
        try do
          user_id = String.to_integer(user_id_str)
          timestamp = String.to_integer(timestamp_str)
          {:ok, {user_id, timestamp, hmac}}
        rescue
          _ -> {:error, :invalid_token_format}
        end
      _ ->
        {:error, :invalid_token_format}
    end
  end
  
  defp verify_expiration(timestamp) do
    current_time = :os.system_time(:second)
    if current_time - timestamp <= @max_token_age do
      :ok
    else
      {:error, :expired}
    end
  end
  
  defp verify_signature(user_id, timestamp, received_hmac) do
    user_id_str = Integer.to_string(user_id)
    timestamp_str = Integer.to_string(timestamp)
    data = user_id_str <> ":" <> timestamp_str
    
    expected_hmac = generate_hmac(data)
    
    if expected_hmac == received_hmac do
      :ok
    else
      {:error, :invalid_signature}
    end
  end
  
  defp verify_not_used(user_id, timestamp) do
    if PasskeyTokenReplay.used?(user_id, timestamp) do
      {:error, :already_used}
    else
      :ok
    end
  end
  
  defp generate_hmac(data) do
    secret = Application.get_env(:xiam, XIAMWeb.Endpoint)[:secret_key_base]
    :crypto.mac(:hmac, :sha256, secret, data)
      |> Base.url_encode64(padding: false)
  end
end
