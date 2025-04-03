defmodule Xiam.Rbac.AccessControl do
  @moduledoc """
  Context module for managing fine-grained access control.
  """

  import Ecto.Query, warn: false
  alias XIAM.Repo
  alias Xiam.Rbac.{EntityAccess, Product, Capability}

  @doc """
  Lists all entity access entries.
  """
  def list_entity_access do
    EntityAccess
    |> order_by([ea], [ea.entity_type, ea.entity_id])
    |> preload([:user, :role])
    |> Repo.all()
  end

  @doc """
  Gets a single entity access entry by id.
  """
  def get_entity_access(id) do
    EntityAccess
    |> preload([:user, :role])
    |> Repo.get(id)
  end

  @doc """
  Sets user access to a specific entity.
  If the ID is provided, it updates an existing record; otherwise, it creates a new one.
  """
  def set_user_access(attrs) do
    case Map.get(attrs, "id") do
      nil ->
        # Create new record
        %EntityAccess{}
        |> EntityAccess.changeset(attrs)
        |> Repo.insert()
      
      id ->
        # Update existing record
        case Repo.get(EntityAccess, id) do
          nil -> {:error, :not_found}
          existing ->
            existing
            |> EntityAccess.changeset(attrs)
            |> Repo.update()
        end
    end
  end

  @doc """
  Gets all access entries for a user.
  """
  def get_user_access(user_id) do
    from(e in EntityAccess,
      where: e.user_id == ^user_id,
      order_by: [e.entity_type, e.entity_id]
    )
    |> Repo.all()
  end

  @doc """
  Deletes an entity access entry.
  """
  def delete_entity_access(%EntityAccess{} = access) do
    Repo.delete(access)
  end

  @doc """
  Creates a new product.
  """
  def create_product(attrs) do
    %Product{}
    |> Product.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a product by id.
  """
  def get_product(id) do
    Repo.get(Product, id)
  end

  @doc """
  Lists all products.
  """
  def list_products do
    from(p in Product,
      preload: :capabilities,
      order_by: p.product_name
    )
    |> Repo.all()
  end

  @doc """
  Updates a product.
  """
  def update_product(%Product{} = product, attrs) do
    product
    |> Product.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a product.
  """
  def delete_product(%Product{} = product) do
    Repo.delete(product)
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
  Gets a capability by id.
  """
  def get_capability(id) do
    Repo.get(Capability, id)
  end

  @doc """
  Lists all capabilities.
  """
  def list_capabilities do
    from(c in Capability,
      preload: :product,
      order_by: c.name
    )
    |> Repo.all()
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
  Gets all capabilities for a product.
  """
  def get_product_capabilities(product_id) do
    from(c in Capability,
      where: c.product_id == ^product_id,
      order_by: c.name
    )
    |> Repo.all()
  end

  @doc """
  Checks if a user has access to a specific entity.
  """
  def has_access?(user_id, entity_type, entity_id) do
    from(e in EntityAccess,
      where:
        e.user_id == ^user_id and
          e.entity_type == ^entity_type and
          e.entity_id == ^entity_id,
      limit: 1
    )
    |> Repo.exists?()
  end

  @doc """
  Gets the role for a user's access to a specific entity.
  """
  def get_user_role(user_id, entity_type, entity_id) do
    from(e in EntityAccess,
      where:
        e.user_id == ^user_id and
          e.entity_type == ^entity_type and
          e.entity_id == ^entity_id,
      select: e.role
    )
    |> Repo.one()
  end
end
