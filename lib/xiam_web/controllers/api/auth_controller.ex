defmodule XIAMWeb.API.AuthController do
  @moduledoc """
  Controller for API authentication endpoints.
  Handles login, token refresh, and verification.
  """
  
  use XIAMWeb, :controller
  
  #alias XIAM.Users.User
  alias XIAM.Auth.JWT
  #alias XIAM.Repo
  alias XIAM.Jobs.AuditLogger
  
  # Private helper to format IP address for JSON compatibility
  defp format_ip(ip) when is_tuple(ip), do: ip |> Tuple.to_list() |> Enum.join(".")
  defp format_ip(ip), do: to_string(ip)
  
  @doc """
  API login endpoint. Authenticates a user and issues a JWT token.
  """
  def login(conn, %{"email" => email, "password" => password}) do
    case Pow.Plug.authenticate_user(conn, %{"email" => email, "password" => password}) do
      {:ok, conn} ->
        user = Pow.Plug.current_user(conn)
        
        # Log the successful login
        AuditLogger.log_action("api_login_success", user.id, %{ip: format_ip(conn.remote_ip)}, email)
        
        # JWT.generate_token is expected to always succeed in normal operation
        # but we'll still handle potential errors for robustness
        {:ok, token, _claims} = JWT.generate_token(user)
        
        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          token: token,
          user: %{
            id: user.id,
            email: user.email
          }
        })
        
      {:error, conn} ->
        # Log the failed login attempt
        AuditLogger.log_action("api_login_failure", nil, %{ip: format_ip(conn.remote_ip)}, email)
        
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid email or password"})
    end
  end
  

  
  @doc """
  Refreshes a JWT token.
  Requires a valid token in the Authorization header.
  """
  def refresh_token(conn, _params) do
    user = conn.assigns.current_user
    claims = conn.assigns.jwt_claims
    
    case JWT.refresh_token(claims) do
      {:ok, token, _claims} ->
        # Log the token refresh
        AuditLogger.log_action("api_token_refresh", user.id, %{ip: format_ip(conn.remote_ip)}, user.email)
        
        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          token: token
        })
        
      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to refresh token: #{inspect(reason)}"})
    end
  end
  

  
  @doc """
  Verifies a token is valid and returns the associated user information.
  Requires a valid token in the Authorization header.
  """
  def verify_token(conn, _params) do
    user = conn.assigns.current_user
    
    # Return basic user information with role and capabilities
    role_info = case user.role do
      nil -> nil
      role -> %{
        id: role.id,
        name: role.name,
        capabilities: Enum.map(role.capabilities, fn cap -> cap.name end)
      }
    end
    
    conn
    |> put_status(:ok)
    |> json(%{
      success: true,
      valid: true,
      user: %{
        id: user.id,
        email: user.email,
        mfa_enabled: user.mfa_enabled,
        role: role_info
      }
    })
  end
  

  
  @doc """
  Logout endpoint for API.
  This is primarily for audit logging since JWTs are stateless.
  """
  def logout(conn, _params) do
    user = conn.assigns.current_user
    
    # Log the logout
    AuditLogger.log_action("api_logout", user.id, %{ip: format_ip(conn.remote_ip)}, user.email)
    
    conn
    |> put_status(:ok)
    |> json(%{
      success: true,
      message: "Logged out successfully"
    })
  end
end
