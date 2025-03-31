defmodule XIAM.Users.User do
  use Ecto.Schema
  use Pow.Ecto.Schema
  use PowAssent.Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    pow_user_fields()

    # MFA fields
    field :mfa_enabled, :boolean, default: false
    field :mfa_secret, :binary
    field :mfa_backup_codes, {:array, :string}

    # Role relationship
    belongs_to :role, Xiam.Rbac.Role

    timestamps()
  end

  @doc """
  Changeset for updating MFA settings.
  """
  def mfa_changeset(user_or_changeset, attrs) do
    user_or_changeset
    |> cast(attrs, [:mfa_enabled, :mfa_secret, :mfa_backup_codes])
    |> validate_required([:mfa_enabled])
    |> validate_mfa_fields()
  end

  @doc """
  Changeset for updating user role.
  """
  def role_changeset(user_or_changeset, attrs) do
    user_or_changeset
    |> cast(attrs, [:role_id])
    |> foreign_key_constraint(:role_id)
  end

  # Private functions

  defp validate_mfa_fields(changeset) do
    changeset
    |> validate_mfa_secret()
    |> validate_mfa_backup_codes()
  end

  defp validate_mfa_secret(changeset) do
    case get_field(changeset, :mfa_enabled) do
      true -> validate_required(changeset, [:mfa_secret])
      _ -> changeset
    end
  end

  defp validate_mfa_backup_codes(changeset) do
    case get_field(changeset, :mfa_enabled) do
      true -> validate_required(changeset, [:mfa_backup_codes])
      _ -> changeset
    end
  end

  @doc """
  Checks if a user has a specific capability.
  """
  def has_capability?(%__MODULE__{} = user, capability_name) when is_binary(capability_name) do
    user = XIAM.Repo.preload(user, :role)

    case user.role do
      nil -> false
      role -> Xiam.Rbac.Role.has_capability?(role, capability_name)
    end
  end

  @doc """
  Generates a new TOTP secret for the user.
  """
  def generate_totp_secret do
    NimbleTOTP.secret()
  end

  @doc """
  Generates backup codes for MFA recovery.
  """
  def generate_backup_codes(count \\ 10) do
    for _ <- 1..count, do: generate_backup_code()
  end

  defp generate_backup_code(length \\ 8) do
    :crypto.strong_rand_bytes(length)
    |> Base.encode32(padding: false, case: :lower)
    |> binary_part(0, length)
  end

  @doc """
  Verifies a TOTP code against the user's secret.
  """
  def verify_totp(%__MODULE__{} = user, totp_code) do
    case user.mfa_secret do
      nil -> {:error, :no_mfa_secret}
      secret -> NimbleTOTP.valid?(secret, totp_code)
    end
  end

  @doc """
  Verifies a backup code against the user's backup codes.
  If valid, removes the used backup code from the list.
  """
  def verify_and_use_backup_code(%__MODULE__{} = user, backup_code) do
    user = XIAM.Repo.preload(user, [])

    if user.mfa_backup_codes && backup_code in user.mfa_backup_codes do
      # Remove the used backup code
      new_backup_codes = List.delete(user.mfa_backup_codes, backup_code)

      {:ok, updated_user} =
        user
        |> change(mfa_backup_codes: new_backup_codes)
        |> XIAM.Repo.update()

      {:ok, updated_user}
    else
      {:error, :invalid_backup_code}
    end
  end

  @doc """
  Changeset for anonymizing user data for GDPR compliance.
  This removes personal information while maintaining references for system integrity.
  """
  def anonymize_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :mfa_enabled, :mfa_secret, :mfa_backup_codes])
    |> validate_required([:email])
    |> unique_constraint(:email)
    # Clear personal data but maintain user record
    |> put_change(:mfa_enabled, false)
    |> put_change(:mfa_secret, nil)
    |> put_change(:mfa_backup_codes, nil)
  end
end
