defmodule Xiam.Rbac.Role do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, warn: false
  
  # Make the Role struct encodable to JSON for API responses
  @derive {Jason.Encoder, only: [:id, :name, :description, :inserted_at, :updated_at]}

  schema "roles" do
    field :name, :string
    field :description, :string

    many_to_many :capabilities, Xiam.Rbac.Capability,
      join_through: "roles_capabilities",
      on_replace: :delete
    has_many :users, XIAM.Users.User

    timestamps()
  end

  @doc false
  def changeset(role, attrs) do
    role
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end

  @doc """
  Returns a list of all roles.
  """
  def list_roles do
    XIAM.Repo.all(__MODULE__)
  end

  @doc """
  Gets a single role by ID.
  Raises `Ecto.NoResultsError` if the role does not exist.
  """
  def get_role!(id), do: XIAM.Repo.get!(__MODULE__, id)

  @doc """
  Gets a single role by name.
  Returns nil if the role does not exist.
  """
  def get_role_by_name(name) when is_binary(name) do
    XIAM.Repo.get_by(__MODULE__, name: name)
  end

  @doc """
  Creates a role.
  """
  def create_role(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> XIAM.Repo.insert()
  end

  @doc """
  Updates a role.
  """
  def update_role(%__MODULE__{} = role, attrs) do
    role
    |> changeset(attrs)
    |> XIAM.Repo.update()
  end

  @doc """
  Deletes a role.
  """
  def delete_role(%__MODULE__{} = role) do
    XIAM.Repo.delete(role)
  end

  @doc """
  Gets a role with preloaded capabilities.
  """
  def get_role_with_capabilities(id) do
    __MODULE__
    |> XIAM.Repo.get(id)
    |> XIAM.Repo.preload(:capabilities)
  end

  @doc """
  Updates the capabilities of a role.
  """
  def update_role_capabilities(%__MODULE__{} = role, capability_ids) when is_list(capability_ids) do
    capabilities = Enum.map(capability_ids, &Xiam.Rbac.Capability.get_capability!/1)

    role
    |> XIAM.Repo.preload(:capabilities)
    |> change()
    |> put_assoc(:capabilities, capabilities)
    |> XIAM.Repo.update()
  end

  @doc """
  Checks if a role has a specific capability.
  Ensures capabilities are loaded before checking.
  Returns false if role is nil.
  """
  def has_capability?(nil, _capability_name), do: false
  def has_capability?(%__MODULE__{} = role, capability_names) when is_list(capability_names) do
    # Ensure capabilities are loaded
    role = if Ecto.assoc_loaded?(role.capabilities) do
      role
    else
      XIAM.Repo.preload(role, :capabilities)
    end

    # Check if role has any of the required capabilities
    Enum.any?(capability_names, fn capability_name ->
      capability_name = if is_atom(capability_name), do: Atom.to_string(capability_name), else: capability_name
      Enum.any?(role.capabilities, fn capability -> capability.name == capability_name end)
    end)
  end
  def has_capability?(%__MODULE__{} = role, capability_name) when is_binary(capability_name) or is_atom(capability_name) do
    # Convert atom to string if needed
    capability_name = if is_atom(capability_name), do: Atom.to_string(capability_name), else: capability_name

    # Ensure capabilities are loaded
    role = if Ecto.assoc_loaded?(role.capabilities) do
      role
    else
      XIAM.Repo.preload(role, :capabilities)
    end

    Enum.any?(role.capabilities, fn capability ->
      capability.name == capability_name
    end)
  end

  @doc """
  Updates a role with both attributes and capabilities.
  """
  def update_role_with_capabilities(%__MODULE__{} = role, attrs, capability_ids) when is_list(capability_ids) do
    capabilities = Enum.map(capability_ids, &Xiam.Rbac.Capability.get_capability!/1)

    role
    |> XIAM.Repo.preload(:capabilities)
    |> changeset(attrs)
    |> put_assoc(:capabilities, capabilities)
    |> XIAM.Repo.update()
  end

  @doc """
  Creates a role with associated capabilities.
  """
  def create_role_with_capabilities(attrs, capability_ids) when is_list(capability_ids) do
    capabilities = Enum.map(capability_ids, &Xiam.Rbac.Capability.get_capability!/1)

    %__MODULE__{}
    |> changeset(attrs)
    |> put_assoc(:capabilities, capabilities)
    |> XIAM.Repo.insert()
  end
end
