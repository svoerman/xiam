defmodule XIAM.Users do
  @behaviour XIAM.Users.Behaviour
  @moduledoc """
  The Users context.
  Provides functions for managing users and their passkeys.
  """

  import Ecto.Query, warn: false
  alias XIAM.Repo
  alias XIAM.Users.User
  alias XIAM.Auth.UserPasskey

  @doc """
  Gets a user by ID.
  """
  def get_user(id), do: Repo.get_by(User, id: id)

  @doc """
  Gets a user by email.
  """
  def get_user_by_email(email), do: Repo.get_by(User, email: email)

  @doc """
  Updates a user's passkey settings.
  """
  def update_user_passkey_settings(%User{} = user, attrs) do
    user
    |> User.passkey_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Lists all passkeys for a user.
  Returns a list of passkeys with friendly names and last used timestamps.
  
  Can accept either a User struct or a user ID directly.
  """
  def list_user_passkeys(%User{} = user) do
    list_user_passkeys(user.id)
  end
  
  def list_user_passkeys(user_id) when is_integer(user_id) do
    # Get the raw passkey records from the database
    UserPasskey.list_by_user(user_id)
  end
  
  @doc """
  Lists all passkeys for a user in a formatted map with only required fields.
  Returns a list of passkey maps with friendly names and timestamps.
  """
  def list_user_passkeys_formatted(%User{} = user) do
    list_user_passkeys(user.id)
    |> Enum.map(fn passkey ->
      %{
        id: passkey.id,
        friendly_name: passkey.friendly_name,
        last_used_at: passkey.last_used_at,
        created_at: passkey.inserted_at
      }
    end)
  end
  
  def list_user_passkeys_formatted(user_id) when is_integer(user_id) do
    list_user_passkeys(user_id)
    |> Enum.map(fn passkey ->
      %{
        id: passkey.id,
        friendly_name: passkey.friendly_name,
        last_used_at: passkey.last_used_at,
        created_at: passkey.inserted_at
      }
    end)
  end

  @doc """
  Deletes a passkey for a user.
  Only allows deletion if the passkey belongs to the user.
  """
  def delete_user_passkey(%User{} = user, passkey_id) do
    passkey = Repo.get(UserPasskey, passkey_id)

    cond do
      is_nil(passkey) ->
        {:error, "Passkey not found"}
      
      passkey.user_id != user.id ->
        {:error, "Passkey does not belong to this user"}
      
      true ->
        result = UserPasskey.delete(passkey)
        
        # Check if this was the last passkey and update user settings if needed
        remaining_passkeys = UserPasskey.list_by_user(user.id)
        
        if Enum.empty?(remaining_passkeys) && user.passkey_enabled do
          user
          |> User.passkey_changeset(%{passkey_enabled: false})
          |> Repo.update()
        end
        
        result
    end
  end
  
  @doc """
  Updates the user's last_sign_in_at timestamp to the current time.
  Used when a user signs in via passkey or other authentication methods.
  """
  def update_user_login_timestamp(%User{} = user) do
    user
    |> Ecto.Changeset.change(%{last_sign_in_at: DateTime.utc_now() |> DateTime.truncate(:second)})
    |> Repo.update()
  end

  @doc """
  Creates a new passkey for a user.
  This is a wrapper around the WebAuthn verification process.
  """
  def create_user_passkey(%User{} = user, attestation_response, challenge, friendly_name) do
    XIAM.Auth.WebAuthn.verify_registration(user, attestation_response, challenge, friendly_name)
  end
end
