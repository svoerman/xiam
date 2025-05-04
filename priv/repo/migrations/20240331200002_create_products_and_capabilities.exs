defmodule Xiam.Repo.Migrations.CreateProductsAndCapabilities do
  use Ecto.Migration

  def change do
    create table(:products) do
      add :product_name, :string, null: false

      timestamps()
    end

    create unique_index(:products, [:product_name])

    # First create the capabilities table if it doesn't exist
    create table(:capabilities) do
      add :name, :string, null: false
      add :description, :string
      add :product_id, references(:products, on_delete: :delete_all)

      timestamps()
    end

    create index(:capabilities, [:product_id])
    create unique_index(:capabilities, [:product_id, :name])
  end
end
