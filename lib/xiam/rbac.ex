defmodule Xiam.Rbac do
  @moduledoc """
  The RBAC context.
  """

  import Ecto.Query, warn: false
  alias XIAM.Repo
  alias Xiam.Rbac.Role
  alias Xiam.Rbac.Capability
  alias Xiam.Rbac.Product

  @doc """
  Returns the list of roles.
  """
  def list_roles do
    Role
    |> preload(:capabilities)
    |> Repo.all()
  end

  @doc """
  Gets a single role.
  """
  def get_role(id) do
    Role
    |> preload(:capabilities)
    |> Repo.get(id)
  end

  @doc """
  Creates a role.
  """
  def create_role(attrs \\ %{}) do
    %Role{}
    |> Role.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a role.
  """
  def update_role(%Role{} = role, attrs) do
    role
    |> Role.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a role.
  """
  def delete_role(%Role{} = role) do
    Repo.delete(role)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking role changes.
  """
  def change_role(%Role{} = role, attrs \\ %{}) do
    Role.changeset(role, attrs)
  end

  @doc """
  Returns the list of capabilities.
  """
  def list_capabilities do
    Capability
    |> order_by([c], c.name)
    |> Repo.all()
  end

  @doc """
  Gets a single capability.
  """
  def get_capability(id) do
    Repo.get(Capability, id)
  end

  @doc """
  Creates a capability.
  """
  def create_capability(attrs \\ %{}) do
    %Capability{}
    |> Capability.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a capability.
  """
  def update_capability(%Capability{} = capability, attrs) do
    capability
    |> Capability.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a capability.
  """
  def delete_capability(%Capability{} = capability) do
    Repo.delete(capability)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking capability changes.
  """
  def change_capability(%Capability{} = capability, attrs \\ %{}) do
    Capability.changeset(capability, attrs)
  end

  @doc """
  Creates a product.
  """
  def create_product(attrs \\ %{}) do
    %Product{}
    |> Product.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns the list of products.
  """
  def list_products do
    Product
    |> preload(:capabilities)
    |> Repo.all()
  end

  @doc """
  Gets a single product.
  """
  def get_product(id) do
    Product
    |> preload(:capabilities)
    |> Repo.get(id)
  end

  @doc """
  Adds a capability to a role.
  """
  def add_capability_to_role(role_id, capability_id) do
    role = get_role(role_id)
    capability = get_capability(capability_id)

    if role && capability do
      # Ensure capabilities are loaded
      role = if Ecto.assoc_loaded?(role.capabilities) do
        role
      else
        Repo.preload(role, :capabilities)
      end

      role
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:capabilities, [capability | role.capabilities])
      |> Repo.update()
    else
      {:error, :not_found}
    end
  end
end
