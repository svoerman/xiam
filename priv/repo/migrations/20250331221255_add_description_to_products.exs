defmodule Xiam.Repo.Migrations.AddDescriptionToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :description, :text
    end
  end
end
