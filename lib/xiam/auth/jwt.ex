defmodule XIAM.Auth.JWT do
  @moduledoc """
  Handles JWT token generation and verification for API authentication.
  Uses Joken library for JWT operations.
  """
  
  use Joken.Config
  
  alias XIAM.Users.User
  alias XIAM.Repo
  
  # Define token expiration (in seconds)
  @token_expiry 3600 * 24 # 24 hours
  
  # Define custom claims
  @impl true
  def token_config do
    default_claims(default_exp: @token_expiry)
    |> add_claim("typ", fn -> "access" end, &(&1 == "access"))
  end
  
  @doc """
  Generates a JWT token for a user.
  
  ## Parameters
  - user: The User struct to generate a token for
  
  ## Returns
  - {:ok, token} on success
  - {:error, reason} on failure
  """
  def generate_token(user) do
    extra_claims = %{
      "sub" => user.id,
      "email" => user.email,
      "role_id" => user.role_id
    }
    
    generate_and_sign(extra_claims)
  end
  
  @doc """
  Verifies a JWT token and returns the claims.
  
  ## Parameters
  - token: The token string to verify
  
  ## Returns
  - {:ok, claims} on success
  - {:error, reason} on failure  
  """
  def verify_token(token) do
    case verify_and_validate(token) do
      {:ok, claims} ->
        {:ok, claims}
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Gets a user from a verified set of claims.
  
  ## Parameters
  - claims: The claims map from a verified token
  
  ## Returns
  - {:ok, user} if user is found
  - {:error, :user_not_found} if user doesn't exist
  """
  def get_user_from_claims(claims) do
    user_id = claims["sub"]
    
    case Repo.get(User, user_id) do
      nil -> {:error, :user_not_found}
      user -> {:ok, user}
    end
  end
  
  @doc """
  Refreshes a token with a new expiry time.
  Used for token refreshing operations.
  
  ## Parameters
  - claims: The claims from the original token
  
  ## Returns
  - {:ok, token} on success
  - {:error, reason} on failure
  """
  def refresh_token(claims) do
    case get_user_from_claims(claims) do
      {:ok, user} -> generate_token(user)
      error -> error
    end
  end
end
