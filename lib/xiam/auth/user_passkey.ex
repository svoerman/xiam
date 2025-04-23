defmodule XIAM.Auth.UserPasskey do
  @moduledoc """
  Schema for storing WebAuthn passkey credentials.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias XIAM.Repo
  
  schema "user_passkeys" do
    belongs_to :user, XIAM.Users.User
    field :credential_id, :binary
    field :public_key, :binary
    field :sign_count, :integer
    field :friendly_name, :string
    field :last_used_at, :utc_datetime
    field :aaguid, :binary
    
    timestamps()
  end
  
  @doc """
  Changeset for creating or updating a passkey.
  """
  def changeset(passkey, attrs) do
    passkey
    |> cast(attrs, [:user_id, :credential_id, :public_key, :sign_count, :friendly_name, :aaguid, :last_used_at])
    |> validate_required([:user_id, :credential_id, :public_key, :sign_count])
    |> unique_constraint(:credential_id)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Finds a passkey by its credential ID.
  """
  def get_by_credential_id(credential_id) do
    Repo.one(from p in __MODULE__, where: p.credential_id == ^credential_id)
  end

  @doc """
  Lists all passkeys for a given user.
  """
  def list_by_user(user_id) do
    Repo.all(from p in __MODULE__, where: p.user_id == ^user_id)
  end
  
  @doc """
  Lists all passkeys with their users.
  """
  def list_all_with_users() do
    Repo.all(from p in __MODULE__, preload: [:user])
  end
  
  @doc """
  Finds a passkey by credential ID, trying multiple formats.
  
  This function tries to match the credential ID in various formats:
  - Exact match (binary or string)
  - Base64URL decoded
  - Base64 decoded
  
  Returns the passkey with user preloaded, or nil if not found.
  """
  def find_by_credential_id_flexible(credential_id) do
    # Try direct match first
    case Repo.one(from p in __MODULE__, where: p.credential_id == ^credential_id, preload: [:user]) do
      %__MODULE__{} = passkey -> passkey
      nil ->
        # Try various transformations
        try_formats = [
          # Try to encode the input if it's binary but not encoded
          {:base64url, Base.url_encode64(credential_id, padding: false)},
          {:base64, Base.encode64(credential_id, padding: false)}
        ]
        
        # If it's a string, try to decode it
        decoded_formats = if is_binary(credential_id) && String.valid?(credential_id) do
          [
            # Try URL-decoded binary
            {:decoded_url, (try do Base.url_decode64!(credential_id, padding: false) rescue _ -> nil end)},
            # Try base64 decoded
            {:decoded_b64, (try do 
              case Base.decode64(credential_id) do
                {:ok, decoded} -> decoded
                _ -> nil 
              end
            rescue _ -> nil end)}
          ]
        else
          []
        end
        
        # Combine all formats to try
        all_formats = try_formats ++ decoded_formats
        
        # Remove nil values
        valid_formats = Enum.filter(all_formats, fn {_format, value} -> value != nil end)
        
        # Try each format
        Enum.reduce_while(valid_formats, nil, fn {format, id}, _acc ->
          case Repo.one(from p in __MODULE__, where: p.credential_id == ^id, preload: [:user]) do
            %__MODULE__{} = passkey -> 
              IO.puts("Found passkey with format: #{format}")
              {:halt, passkey}
            nil -> {:cont, nil}
          end
        end)
    end
  end

  @doc """
  Updates the sign count for a passkey.
  """
  def update_sign_count(passkey, new_sign_count) do
    passkey
    |> changeset(%{sign_count: new_sign_count, last_used_at: DateTime.utc_now()})
    |> Repo.update()
  end

  @doc """
  Updates the last_used_at timestamp for a passkey.
  """
  def update_last_used(passkey) do
    passkey
    |> changeset(%{last_used_at: DateTime.utc_now()})
    |> Repo.update()
  end

  @doc """
  Deletes a passkey.
  """
  def delete(passkey) do
    Repo.delete(passkey)
  end
end
