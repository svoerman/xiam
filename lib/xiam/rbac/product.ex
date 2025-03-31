defmodule Xiam.Rbac.Product do
  use Ecto.Schema
  import Ecto.Changeset

  schema "products" do
    field :product_name, :string
    field :description, :string

    has_many :capabilities, Xiam.Rbac.Capability

    timestamps()
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [:product_name, :description])
    |> validate_required([:product_name])
    |> unique_constraint(:product_name)
  end
end
