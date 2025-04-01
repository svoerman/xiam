defmodule XIAMWeb.Plugs.APIAuthPlug do
  @moduledoc """
  Plug for API authentication using JWT tokens.
  Verifies the JWT token in the Authorization header and adds the user to the connection.
  """
  
  import Plug.Conn
  
  alias XIAMWeb.Plugs.AuthHelpers
  
  @doc """
  Initialize the plug options.
  """
  def init(opts), do: opts
  
  @doc """
  Call function for the plug.
  Verifies the JWT token in the Authorization header and adds the user to the connection.
  If token is invalid or missing, returns 401 Unauthorized.
  """
  def call(conn, _opts) do
    with {:ok, token} <- AuthHelpers.extract_token(conn),
         {:ok, user, claims} <- AuthHelpers.verify_jwt_token(token) do
      conn
      |> assign(:current_user, user)
      |> assign(:jwt_claims, claims)
    else
      {:error, :token_not_found} ->
        AuthHelpers.unauthorized_response(conn, "Authorization header missing or invalid")
        
      {:error, :invalid_token_format} ->
        AuthHelpers.unauthorized_response(conn, "Invalid token format")
        
      {:error, :user_not_found} ->
        AuthHelpers.unauthorized_response(conn, "User not found")
        
      _error ->
        AuthHelpers.unauthorized_response(conn, "Invalid token")
    end
  end
  
  @doc """
  Checks if a user has a specific capability.
  Delegate to AuthHelpers to maintain consistent authorization logic.
  """
  def has_capability?(user, capability) do
    AuthHelpers.has_capability?(user, capability)
  end
end
