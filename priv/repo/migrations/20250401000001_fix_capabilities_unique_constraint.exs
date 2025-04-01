defmodule XIAM.Repo.Migrations.FixCapabilitiesUniqueConstraint do
  use Ecto.Migration

  def change do
    # Drop the name-only unique index constraint that's causing conflicts
    drop_if_exists index(:capabilities, [:name])
    
    # Keep only the compound constraint on product_id and name
    # This allows duplicate capability names across different products
    # But ensures uniqueness within a single product
  end
end