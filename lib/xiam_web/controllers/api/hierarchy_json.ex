defmodule XIAMWeb.API.HierarchyJSON do
  @moduledoc """
  JSON rendering for the hierarchy API responses.
  """
  
  alias XIAM.Hierarchy.Node
  
  @doc """
  Renders a list of nodes.
  """
  def index(%{nodes: nodes}) do
    %{data: for(node <- nodes, do: node_data(node))}
  end
  
  @doc """
  Renders a single node with its children.
  """
  def show(%{node: node, children: children}) do
    %{
      data: Map.merge(
        node_data(node),
        %{children: for(child <- children, do: node_data(child))}
      )
    }
  end
  
  # Private helpers
  
  defp node_data(%Node{} = node) do
    %{
      id: node.id,
      name: node.name,
      node_type: node.node_type,
      path: node.path,
      parent_id: node.parent_id,
      metadata: node.metadata,
      inserted_at: node.inserted_at,
      updated_at: node.updated_at
    }
  end
end
