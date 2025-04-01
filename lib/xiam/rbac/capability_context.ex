defmodule XIAM.Rbac.CapabilityContext do
  @moduledoc """
  Context module for managing capabilities in the RBAC system.
  Uses the CRUDBehavior for standard operations to reduce duplication.
  """

  use XIAM.Shared.CRUDBehavior,
    schema: Xiam.Rbac.Capability,
    preloads: [:product],
    pagination: true,
    sort_fields: [:name, :inserted_at, :updated_at]

  alias Xiam.Rbac.Capability

  @doc """
  Lists all capabilities with optional filtering.
  """
  def list_capabilities(filters \\ %{}, pagination_params \\ %{}) do
    list_all(filters, pagination_params)
  end

  @doc """
  Gets a capability by id.
  """
  def get_capability(id), do: get(id)

  @doc """
  Creates a new capability.
  """
  def create_capability(attrs \\ %{}), do: create(attrs)

  @doc """
  Updates a capability.
  """
  def update_capability(%Capability{} = capability, attrs) do
    capability
    |> Capability.changeset(attrs)
    |> XIAM.Repo.update()
  end

  @doc """
  Deletes a capability.
  """
  def delete_capability(%Capability{} = capability), do: delete(capability)

  @doc """
  Gets all capabilities for a product.
  """
  def get_product_capabilities(product_id) do
    Capability
    |> where([c], c.product_id == ^product_id)
    |> order_by([c], c.name)
    |> XIAM.Repo.all()
  end

  @doc """
  Apply custom filtering logic for capabilities.
  """
  def apply_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:product_id, product_id}, query ->
        where(query, [c], c.product_id == ^product_id)
      
      {:name, name}, query ->
        where(query, [c], ilike(c.name, ^"%#{name}%"))
      
      {_, _}, query -> 
        query
    end)
  end

  @doc """
  Apply default sorting by name.
  """
  def apply_sorting(query, nil, _), do: order_by(query, [c], c.name)
  def apply_sorting(query, sort_by, sort_order), do: super(query, sort_by, sort_order)
end