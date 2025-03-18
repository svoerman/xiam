defmodule XIAMWeb.Plugs.APIAuthPlug do
  @moduledoc """
  Plug for API authentication using JWT tokens.
  Verifies the JWT token in the Authorization header and adds the user to the connection.
  """
  
  import Plug.Conn
  import Phoenix.Controller
  
  alias XIAM.Auth.JWT
  alias XIAM.Repo
  
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
    with {:ok, token} <- extract_token(conn),
         {:ok, claims} <- JWT.verify_token(token),
         {:ok, user} <- JWT.get_user_from_claims(claims) do
      # Preload the role and capabilities for authorization checks
      user = user |> Repo.preload(role: :capabilities)
      
      conn
      |> assign(:current_user, user)
      |> assign(:jwt_claims, claims)
    else
      {:error, :token_not_found} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authorization header missing or invalid"})
        |> halt()
        
      {:error, :invalid_token_format} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid token format"})
        |> halt()
        
      {:error, :user_not_found} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "User not found"})
        |> halt()
        
      _error ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid token"})
        |> halt()
    end
  end
  
  # Extracts the JWT token from the Authorization header.
  # Expected format: "Bearer <token>"
  #
  # Returns:
  # - {:ok, token} if token is found and correctly formatted
  # - {:error, :token_not_found} if token is missing
  # - {:error, :invalid_token_format} if token format is invalid
  defp extract_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      ["bearer " <> token] -> {:ok, token}
      [] -> {:error, :token_not_found}
      _ -> {:error, :invalid_token_format}
    end
  end
end
