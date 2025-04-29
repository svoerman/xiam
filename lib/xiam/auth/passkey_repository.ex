defmodule XIAM.Auth.PasskeyRepository do
  @moduledoc """
  Repository for passkey operations.
  
  This module handles database access for WebAuthn passkeys,
  separating data access concerns from the business logic in the
  CredentialManager.
  """
  
  alias XIAM.Users.User
  alias XIAM.Auth.UserPasskey
  alias XIAM.Repo
  import Ecto.Query
  require Logger
  
  @doc """
  Fetches a user by email.
  
  ## Returns
  - `{:ok, user}` if user is found
  - `{:error, :user_not_found}` if no user with this email exists
  """
  def get_user_by_email(email) when is_binary(email) do
    case Repo.get_by(User, email: email) do
      %User{} = user -> {:ok, user}
      nil -> {:error, :user_not_found}
    end
  end
  
  @doc """
  Fetches all passkeys for a user.
  
  ## Parameters
  - `user` - User struct to fetch passkeys for
  
  ## Returns
  - List of passkeys (may be empty)
  """
  def get_user_passkeys(%User{} = user) do
    user
    |> Ecto.assoc(:passkeys)
    |> Repo.all()
  end
  
  @doc """
  Fetches a passkey and its associated user by credential ID (base64 encoded).
  
  ## Parameters
  - `credential_id_b64` - Base64-URL encoded credential ID
  
  ## Returns
  - `{:ok, passkey, user}` if found
  - `{:error, reason}` if not found or on error
  """
  def get_passkey_with_user(credential_id_b64, opts \\ []) when is_binary(credential_id_b64) do
    suppress_log = Keyword.get(opts, :suppress_log, false)
    query =
      from pk in UserPasskey,
      where: pk.credential_id == ^credential_id_b64,
      join: u in assoc(pk, :user),
      preload: [user: u],
      limit: 1

    case Repo.one(query) do
      %UserPasskey{user: %User{} = user} = passkey ->
        {:ok, passkey, user}
      nil ->
        unless suppress_log do
          Logger.warning("Passkey not found for credential ID (base64): #{credential_id_b64}")
        end
        {:error, :credential_not_found}
      _ ->
        unless suppress_log do
          Logger.error("Unexpected result fetching passkey for credential ID (base64): #{credential_id_b64}")
        end
        {:error, :database_error}
    end
  end
  
  @doc """
  Updates the sign count on a passkey.
  
  ## Parameters
  - `passkey` - UserPasskey struct to update
  - `new_sign_count` - New sign count value
  
  ## Returns
  - `{:ok, updated_passkey}` on success
  - `{:error, changeset}` on validation error
  """
  def update_sign_count(passkey, new_sign_count) do
    passkey
    |> UserPasskey.changeset(%{sign_count: new_sign_count})
    |> Repo.update()
  end
end
