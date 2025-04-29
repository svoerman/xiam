defmodule XIAMWeb.AuthController do
  @moduledoc """
  Controller for handling passkey authentication completion.
  This controller is responsible for creating a proper Pow session
  after a successful passkey authentication via the API.
  """
  use XIAMWeb, :controller
  alias XIAM.Users
  alias XIAM.Auth.TokenValidator
  
  @doc """
  Completes the passkey authentication process by creating a proper Pow session.
  This endpoint is hit after a successful API-based passkey authentication.
  """
  def complete_passkey_auth(conn, %{"auth_token" => encoded_token}) do
    # Decode the token from URL-safe format
    token = URI.decode_www_form(encoded_token)
    
    case TokenValidator.validate_token(token) do
      {:ok, {user_id, timestamp}} ->
        handle_valid_token(conn, user_id, timestamp)
        
      {:error, :expired} ->
        conn
        |> put_flash(:error, "Authentication token expired")
        |> redirect(to: ~p"/session/new")
        
      {:error, :invalid_signature} ->
        conn
        |> put_flash(:error, "Invalid authentication token")
        |> redirect(to: ~p"/session/new")
        
      {:error, :already_used} ->
        conn
        |> put_flash(:error, "This authentication token has already been used. Please sign in again.")
        |> redirect(to: ~p"/session/new")
        
      {:error, _} ->
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
  
  # Handle authenticated user
  defp handle_valid_token(conn, user_id, timestamp) do
    # Mark the token as used to prevent replay
    TokenValidator.mark_used(user_id, timestamp)
    
    # Valid token, get the user
    user = Users.get_user(user_id)
    
    # Fetch redirect path BEFORE Pow potentially modifies the conn session
    original_request_path = get_session(conn, "request_path")
    
    # Use Pow.Plug.create to properly initialize the Pow session
    conn = Pow.Plug.create(conn, user, plug: Pow.Plug.Session, otp_app: :xiam)
    
    # Also update the last login timestamp for the user
    {:ok, _} = XIAM.Users.update_user_login_timestamp(user)
    
    # Determine redirect path
    redirect_path = case original_request_path do
      nil -> "/admin" # Default to admin page if no specific path was requested
      path -> path
    end
  
    # Redirect to the desired path with success message
    conn
    |> delete_session("request_path")
    |> put_flash(:info, "Successfully signed in with passkey")
    |> redirect(to: redirect_path)
  end
end
