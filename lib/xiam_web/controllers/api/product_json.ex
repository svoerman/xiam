defmodule XIAMWeb.API.ProductJSON do
  @moduledoc """
  JSON view for ProductController responses.
  """
  alias Xiam.Rbac.Product

  @doc """
  Renders a list of products.
  """
  def index(%{products: products}) do
    %{data: for(product <- products, do: data(product))}
  end

  @doc """
  Renders a single product.
  """
  def show(%{product: product}) do
    %{data: data(product)}
  end

  @doc """
  Renders product data for JSON response.
  """
  def data(%Product{} = product) do
    %{
      id: product.id,
      product_name: product.product_name,
      description: product.description,
      inserted_at: product.inserted_at,
      updated_at: product.updated_at
    }
  end
end