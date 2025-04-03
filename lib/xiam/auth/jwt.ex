defmodule XIAM.Auth.JWT do
  @moduledoc """
  Handles JWT token generation and verification for API authentication.
  Uses the :jose library directly for JWT operations.
  """

  # REMOVED: Hardcoded signing key - DO NOT USE
  # @signing_key "test_secret_key_for_testing_only_not_for_production"

  # Define token expiration (in seconds)
  @token_expiry Application.compile_env(:xiam, :jwt_token_expiry, 3600 * 24) # Default 24 hours

  alias XIAM.Users.User
  alias XIAM.Repo

  # Helper function to get the signing key from configuration
  defp get_signing_key! do
    Application.fetch_env!(:xiam, :jwt_signing_key)
  rescue
    KeyError ->
      raise """
      Missing JWT signing key configuration.
      Ensure :jwt_signing_key is set in your config (e.g., config/runtime.exs from ENV).
      """
  end

  @doc """
  Generates a JWT token for a user.

  ## Parameters
  - user: The User struct to generate a token for

  ## Returns
  - {:ok, token, claims} on success
  - {:error, reason} on failure
  """
  def generate_token(user) do
    signing_key = get_signing_key!()
    claims = %{
      "sub" => user.id,
      "email" => user.email,
      "role_id" => user.role_id,
      "exp" => :os.system_time(:second) + @token_expiry,
      "iat" => :os.system_time(:second),
      "typ" => "access"
    }

    jwk = :jose_jwk.from_oct(signing_key)
    jws = :jose_jws.from_map(%{"alg" => "HS256"})
    jwt = :jose_jwt.from_map(claims)

    {_, token} = :jose_jwt.sign(jwk, jws, jwt)
    {_, encoded} = :jose_jws.compact(token)

    {:ok, encoded, claims}
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
    signing_key = get_signing_key!()
    jwk = :jose_jwk.from_oct(signing_key)

    try do
      # Verify the token using JOSE
      {verified, jwt, _jws} = :jose_jwt.verify_strict(jwk, ["HS256"], token)

      if verified do
        claims = :jose_jwt.to_map(jwt) |> elem(1)

        # Validate token expiry
        exp = Map.get(claims, "exp", 0)
        now = :os.system_time(:second)
        if exp > now do
          {:ok, claims}
        else
          {:error, :token_expired}
        end
      else
        {:error, :invalid_token}
      end
    rescue
      _ -> {:error, :invalid_token}
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
    signing_key = get_signing_key!()
    case get_user_from_claims(claims) do
      {:ok, user} ->
        # Use a different timestamp to ensure a different token
        timestamp = :os.system_time(:second) + 1 # Force a timestamp change

        claims = %{
          "sub" => user.id,
          "email" => user.email,
          "role_id" => user.role_id,
          "exp" => timestamp + @token_expiry,
          "iat" => timestamp,
          "typ" => "access"
        }

        jwk = :jose_jwk.from_oct(signing_key)
        jws = :jose_jws.from_map(%{"alg" => "HS256"})
        jwt = :jose_jwt.from_map(claims)

        {_, token} = :jose_jwt.sign(jwk, jws, jwt)
        {_, encoded} = :jose_jws.compact(token)

        {:ok, encoded, claims}
      error -> error
    end
  end
end
