defmodule XIAMWeb.AuthController do
  @moduledoc """
  Controller for handling passkey authentication completion.
  This controller is responsible for creating a proper Pow session
  after a successful passkey authentication via the API.
  """
  use XIAMWeb, :controller
  alias XIAM.Users
  alias XIAM.Auth.PasskeyTokenReplay
  
  @max_token_age 300 # 5 minutes in seconds
  
  @doc """
  Completes the passkey authentication process by creating a proper Pow session.
  This endpoint is hit after a successful API-based passkey authentication.
  """
  def complete_passkey_auth(conn, %{"auth_token" => token}) do
    # Decode the token from URL-safe format
    token = URI.decode_www_form(token)
    
    # Parse token parts: user_id:timestamp:hmac
    case String.split(token, ":", parts: 3) do
      [user_id_str, timestamp_str, received_hmac] ->
        # Convert user_id to integer
        user_id = String.to_integer(user_id_str)
        timestamp = String.to_integer(timestamp_str)
        
        # Check if token is expired
        current_time = :os.system_time(:second)
        if current_time - timestamp > @max_token_age do
          conn
          |> put_flash(:error, "Authentication token expired")
          |> redirect(to: ~p"/session/new")
        else
          # Verify HMAC using the same secret as the API controller
          secret = Application.get_env(:xiam, XIAMWeb.Endpoint)[:secret_key_base]
          expected_hmac = :crypto.mac(:hmac, :sha256, secret, user_id_str <> ":" <> timestamp_str)
            |> Base.url_encode64(padding: false)
            
          if expected_hmac == received_hmac do
            # REPLAY PROTECTION: Check if this token was already used
            if PasskeyTokenReplay.used?(user_id, timestamp) do
              conn
              |> put_flash(:error, "This authentication token has already been used. Please sign in again.")
              |> redirect(to: ~p"/session/new")
            else
              PasskeyTokenReplay.mark_used(user_id, timestamp)
              # Valid token, get the user
              user = Users.get_user(user_id)
        
              # Fetch redirect path BEFORE Pow potentially modifies the conn session
              original_request_path = get_session(conn, "request_path")
              # IO.puts "AuthController: Checking session for 'request_path': #{inspect(original_request_path)}"
              
              # Use Pow.Plug.create to properly initialize the Pow session
              conn = Pow.Plug.create(conn, user, plug: Pow.Plug.Session, otp_app: :xiam)
              
              # Also update the last login timestamp for the user
              {:ok, _} = XIAM.Users.update_user_login_timestamp(user)
              
              # Determine redirect path using the value fetched earlier
              redirect_path = case original_request_path do
                nil -> 
                  # IO.puts "AuthController: No 'request_path' found, defaulting to /admin"
                  "/admin" # Default to admin page if no specific path was requested
                path -> 
                  # IO.puts "AuthController: Found 'request_path' #{path}, redirecting..."
                  path
              end
            
              # Redirect to the desired path with success message
              conn
              |> delete_session("request_path")
              |> put_flash(:info, "Successfully signed in with passkey")
              |> redirect(to: redirect_path)
            end
          else
            # Invalid HMAC
            conn
            |> put_flash(:error, "Invalid authentication token")
            |> redirect(to: ~p"/session/new")
          end
        end
        
      # Token format is invalid
      _ ->
        conn
        |> put_flash(:error, "Invalid authentication token format")
        |> redirect(to: ~p"/session/new")
    end
  end
  
  # Fallback for when no token is provided
  def complete_passkey_auth(conn, _params) do
    conn
    |> put_flash(:error, "Missing authentication token")
    |> redirect(to: ~p"/session/new")
  end
end
