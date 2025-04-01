defmodule XIAM.Rbac.ProductContext do
  @moduledoc """
  Context module for managing products in the RBAC system.
  Uses the CRUDBehavior for standard operations to reduce duplication.
  """

  use XIAM.Shared.CRUDBehavior,
    schema: Xiam.Rbac.Product,
    preloads: [:capabilities],
    pagination: true,
    sort_fields: [:product_name, :inserted_at, :updated_at]

  alias Xiam.Rbac.Product

  @doc """
  Lists all products with optional filtering.
  """
  def list_products(filters \\ %{}, pagination_params \\ %{}) do
    list_all(filters, pagination_params)
  end

  @doc """
  Gets a product by id.
  """
  def get_product(id), do: get(id)

  @doc """
  Creates a new product.
  """
  def create_product(attrs), do: create(attrs)

  @doc """
  Updates a product.
  """
  def update_product(%Product{} = product, attrs) do
    product
    |> Product.changeset(attrs)
    |> XIAM.Repo.update()
  end

  @doc """
  Deletes a product.
  """
  def delete_product(%Product{} = product), do: delete(product)

  @doc """
  Implement custom filtering for products.
  """
  def apply_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:product_name, name}, query ->
        where(query, [p], ilike(p.product_name, ^"%#{name}%"))
      
      {_, _}, query -> 
        query
    end)
  end

  @doc """
  Apply default sorting by product_name.
  """
  def apply_sorting(query, nil, _), do: order_by(query, [p], p.product_name)
  def apply_sorting(query, sort_by, sort_order), do: super(query, sort_by, sort_order)
end