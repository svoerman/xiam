defmodule Xiam.Rbac.EntityAccess do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :user_id, :entity_type, :entity_id, :role_id]}
  schema "entity_access" do
    belongs_to :user, XIAM.Users.User
    field :entity_type, :string
    field :entity_id, :integer
    belongs_to :role, Xiam.Rbac.Role

    timestamps()
  end

  @doc false
  def changeset(entity_access, attrs) do
    entity_access
    |> cast(attrs, [:id, :user_id, :entity_type, :entity_id, :role_id])
    |> validate_required([:user_id, :entity_type, :entity_id, :role_id])
    |> unique_constraint([:user_id, :entity_type, :entity_id])
    |> foreign_key_constraint(:role_id)
  end
end
