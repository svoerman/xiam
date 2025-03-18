defmodule XIAM.Consent.ConsentType do
  @moduledoc """
  Schema for consent types.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "consent_types" do
    field :name, :string
    field :description, :string
    field :required, :boolean, default: false
    field :active, :boolean, default: true

    timestamps()
  end

  @doc false
  def changeset(consent_type, attrs) do
    consent_type
    |> cast(attrs, [:name, :description, :required, :active])
    |> validate_required([:name])
  end
end
