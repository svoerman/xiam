defmodule XIAMWeb.API.AuthController do
  @moduledoc """
  Controller for API authentication endpoints.
  Handles login, token refresh, and verification.
  """

  use XIAMWeb, :controller
  alias XIAMWeb.Plugs.APIAuthorizePlug

  #alias XIAM.Users.User
  alias XIAM.Auth.JWT
  #alias XIAM.Repo
  alias XIAM.Jobs.AuditLogger

  # Login is unprotected (happens before authentication)
  # Other actions require authentication but no specific capability
  plug APIAuthorizePlug, nil when action in [:refresh_token, :verify_token, :logout]

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
        AuditLogger.log_action("api_login_success", user.id, %{"resource_type" => "api", "ip" => format_ip(conn.remote_ip)}, email)

        if user.mfa_enabled do
          # For MFA-enabled users, return a partial token
          {:ok, partial_token, _claims} = JWT.generate_partial_token(user)
          
          conn
          |> put_status(:ok)
          |> json(%{
            success: true,
            mfa_required: true,
            partial_token: partial_token,
            user: %{
              id: user.id,
              email: user.email
            }
          })
        else
          # For users without MFA, proceed with normal flow
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
        end

      {:error, conn} ->
        # Log the failed login attempt
        AuditLogger.log_action("api_login_failure", nil, %{"resource_type" => "api", "ip" => format_ip(conn.remote_ip)}, email)

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
        AuditLogger.log_action("api_token_refresh", user.id, %{"resource_type" => "api", "ip" => format_ip(conn.remote_ip)}, user.email)

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
    AuditLogger.log_action("api_logout", user.id, %{"resource_type" => "api", "ip" => format_ip(conn.remote_ip)}, user.email)

    conn
    |> put_status(:ok)
    |> json(%{
      success: true,
      message: "Logged out successfully"
    })
  end

  @doc """
  MFA challenge endpoint.
  Requires a partial token in the Authorization header.
  Returns information needed for the MFA challenge.
  """
  def mfa_challenge(conn, _params) do
    user = conn.assigns.current_user
    
    # Verify this is a user with MFA enabled
    if user.mfa_enabled do
      conn
      |> put_status(:ok)
      |> json(%{
        success: true,
        message: "Please enter the code from your authenticator app"
      })
    else
      conn
      |> put_status(:bad_request)
      |> json(%{
        success: false,
        error: "MFA is not enabled for this user"
      })
    end
  end

  @doc """
  MFA verification endpoint.
  Verifies the TOTP code and issues a full JWT token if successful.
  Requires a partial token in the Authorization header.
  """
  def mfa_verify(conn, %{"code" => totp_code}) do
    user = conn.assigns.current_user
    claims = conn.assigns.jwt_claims
    
    # Verify this is a partial token for MFA
    if claims["typ"] != "mfa_required" or !claims["mfa_pending"] do
      conn
      |> put_status(:bad_request)
      |> json(%{
        success: false,
        error: "Invalid authentication flow. Please login again."
      })
    else
      # Verify the TOTP code
      case XIAM.Users.User.verify_totp(user, totp_code) do
        true ->
          # Log the successful MFA verification
          AuditLogger.log_action("api_mfa_success", user.id, %{"resource_type" => "api", "ip" => format_ip(conn.remote_ip)}, user.email)
          
          # Generate a full token
          {:ok, token, _claims} = JWT.generate_token(user)
          
          conn
          |> put_status(:ok)
          |> json(%{
            success: true,
            token: token,
            message: "MFA verification successful"
          })
          
        false ->
          # Log the failed MFA attempt
          AuditLogger.log_action("api_mfa_failure", user.id, %{"resource_type" => "api", "ip" => format_ip(conn.remote_ip)}, user.email)
          
          conn
          |> put_status(:unauthorized)
          |> json(%{
            success: false,
            error: "Invalid MFA code"
          })
      end
    end
  end
end
