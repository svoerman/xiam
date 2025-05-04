defmodule XIAM.Repo.Migrations.AddLtreeExtension do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS ltree", "DROP EXTENSION IF EXISTS ltree"
  end
end
