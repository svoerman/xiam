defmodule Xiam.Repo.Migrations.CreateProductsAndCapabilities do
  use Ecto.Migration

  def change do
    create table(:products) do
      add :product_name, :string, null: false

      timestamps()
    end

    create unique_index(:products, [:product_name])

    # Add product_id to existing capabilities table
    alter table(:capabilities) do
      add :product_id, references(:products, on_delete: :delete_all)
    end

    create index(:capabilities, [:product_id])
    create unique_index(:capabilities, [:product_id, :name])
  end
end
