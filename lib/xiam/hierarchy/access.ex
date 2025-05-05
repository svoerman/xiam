defmodule XIAM.Hierarchy.Access do
  @moduledoc """
  Schema representing a user's access grant to a node in the hierarchy.
  Users are granted access to nodes, which implicitly grants access to all children.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "hierarchy_access" do
    field :access_path, :string  # ltree stored as string

    belongs_to :user, XIAM.Users.User
    belongs_to :role, Xiam.Rbac.Role

    timestamps()
  end

  @doc """
  Changeset for creating and updating hierarchy access.
  """
  def changeset(access, attrs) do
    access
    |> cast(attrs, [:user_id, :access_path, :role_id])
    |> validate_required([:user_id, :access_path, :role_id])
    |> unique_constraint([:user_id, :access_path])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:role_id)
  end
end
