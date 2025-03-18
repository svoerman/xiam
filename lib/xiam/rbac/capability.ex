defmodule XIAM.RBAC.Capability do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, warn: false

  schema "capabilities" do
    field :name, :string
    field :description, :string

    many_to_many :roles, XIAM.RBAC.Role, join_through: "roles_capabilities"

    timestamps()
  end

  @doc false
  def changeset(capability, attrs) do
    capability
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end

  @doc """
  Returns a list of all capabilities.
  """
  def list_capabilities do
    XIAM.Repo.all(__MODULE__)
  end

  @doc """
  Gets a single capability by ID.
  Raises `Ecto.NoResultsError` if the capability does not exist.
  """
  def get_capability!(id), do: XIAM.Repo.get!(__MODULE__, id)

  @doc """
  Gets a single capability by name.
  Returns nil if the capability does not exist.
  """
  def get_capability_by_name(name) when is_binary(name) do
    XIAM.Repo.get_by(__MODULE__, name: name)
  end

  @doc """
  Creates a capability.
  """
  def create_capability(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> XIAM.Repo.insert()
  end

  @doc """
  Updates a capability.
  """
  def update_capability(%__MODULE__{} = capability, attrs) do
    capability
    |> changeset(attrs)
    |> XIAM.Repo.update()
  end

  @doc """
  Deletes a capability.
  """
  def delete_capability(%__MODULE__{} = capability) do
    XIAM.Repo.delete(capability)
  end
end
