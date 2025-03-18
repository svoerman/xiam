defmodule XIAM.System.Setting do
  use Ecto.Schema
  import Ecto.Changeset

  schema "settings" do
    field :key, :string
    field :value, :string
    field :data_type, :string, default: "string"
    field :category, :string, default: "general"
    field :description, :string
    field :is_editable, :boolean, default: true

    timestamps()
  end

  @doc """
  Changeset for settings.
  """
  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:key, :value, :data_type, :category, :description, :is_editable])
    |> validate_required([:key, :value])
    |> validate_inclusion(:data_type, ["string", "integer", "boolean", "float", "json"])
    |> unique_constraint(:key)
  end
end
