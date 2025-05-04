defmodule XIAM.Hierarchy.Node do
  @moduledoc """
  Schema representing a node in the hierarchical tree structure.
  Each node can have a user-defined type, allowing for flexible hierarchies.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "hierarchy_nodes" do
    field :path, :string  # ltree stored as string
    field :node_type, :string  # User-defined type (was integer before)
    field :name, :string
    field :metadata, :map
    
    belongs_to :parent, __MODULE__
    has_many :children, __MODULE__, foreign_key: :parent_id
    
    timestamps()
  end
  
  @doc """
  Changeset for creating and updating a node.
  The path is set by the context, not directly in the changeset.
  """
  def changeset(node, attrs) do
    node
    |> cast(attrs, [:name, :node_type, :parent_id, :metadata])
    |> validate_required([:name, :node_type])
    |> foreign_key_constraint(:parent_id)
  end
  
  @doc """
  Returns the node type as is, since types are now strings defined by users.
  This maintains compatibility with existing code that might call this function.
  """
  def node_type_name(type_value), do: type_value
end
