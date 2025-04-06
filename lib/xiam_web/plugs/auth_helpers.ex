defmodule XIAMWeb.Plugs.AuthHelpers do
  @moduledoc """
  Shared authentication and authorization helper functions to reduce duplication
  across authentication plugs.
  """

  import Plug.Conn
  import Phoenix.Controller
  require Logger

  alias XIAM.Auth.JWT
  alias XIAM.Repo
  alias XIAM.Users.User

  @doc """
  Extracts the JWT token from the Authorization header.
  Expected format: "Bearer <token>"

  Returns:
  - {:ok, token} if token is found and correctly formatted
  - {:error, :token_not_found} if token is missing
  - {:error, :invalid_token_format} if token format is invalid
  """
  def extract_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> 
        # Log the token (for debugging only, remove in production)
        Logger.debug("Received Bearer token: #{String.slice(token, 0, 10)}...")
        {:ok, token}
      ["bearer " <> token] -> 
        # Log the token (for debugging only, remove in production)
        Logger.debug("Received bearer token: #{String.slice(token, 0, 10)}...")
        {:ok, token}
      [] -> {:error, :token_not_found}
      _ -> {:error, :invalid_token_format}
    end
  end

  @doc """
  Verifies a JWT token and returns the associated user.

  Returns:
  - {:ok, user} if token is valid and user is found
  - {:error, reason} if token verification fails or user not found
  """
  def verify_jwt_token(token) do
    with {:ok, claims} <- JWT.verify_token(token),
         {:ok, user} <- JWT.get_user_from_claims(claims) do
      # Preload the role and capabilities for authorization checks
      user = user |> Repo.preload(role: :capabilities)
      {:ok, user, claims}
    end
  end

  @doc """
  Checks if a user has a specific capability.

  Returns:
  - true if user has the capability
  - false if user does not have the capability or user is nil
  """
  def has_capability?(nil, _capability), do: false
  def has_capability?(user, capability) do
    # Return false if user has no role
    if is_nil(user.role) do
      false
    else
      # Ensure role and capabilities are loaded
      user = if Ecto.assoc_loaded?(user.role) do
        user
      else
        Repo.preload(user, role: :capabilities)
      end

      # Delegate to User module for actual capability check
      User.has_capability?(user, capability)
    end
  end

  @doc """
  Checks if a user has admin privileges.

  Returns:
  - true if user has admin privileges
  - false if user does not have admin privileges or user is nil
  """
  def has_admin_privileges?(nil), do: false
  def has_admin_privileges?(%User{} = user) do
    # Check the direct admin flag first for efficiency
    if user.admin do
      true
    else
      # If not directly admin, check role capabilities (preloading if necessary)
      user =
        if Ecto.assoc_loaded?(user.role) and Ecto.assoc_loaded?(user.role.capabilities) do
          user
        else
          user |> Repo.preload(role: :capabilities)
        end

      case user.role do
        nil -> false
        %Xiam.Rbac.Role{} = role ->
          Enum.any?(role.capabilities, fn %Xiam.Rbac.Capability{} = capability ->
            capability.name == "admin_access"
          end)
      end
    end
  end

  @doc """
  Creates error response for unauthorized access.
  """
  def unauthorized_response(conn, reason \\ "Unauthorized") do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: reason})
    |> halt()
  end

  @doc """
  Creates forbidden response for insufficient permissions.
  """
  def forbidden_response(conn, reason \\ "Insufficient permissions") do
    conn
    |> put_status(:forbidden)
    |> json(%{error: reason})
    |> halt()
  end
end
