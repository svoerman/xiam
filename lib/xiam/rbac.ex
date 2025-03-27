defmodule XIAM.RBAC do
  @moduledoc """
  The RBAC context.
  """

  import Ecto.Query, warn: false
  alias XIAM.Repo
  alias XIAM.RBAC.Role
  alias XIAM.RBAC.Capability

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
end
