defmodule XIAM.Hierarchy.BatchCreateNodesFix do
  @moduledoc """
  This module implements the missing batch_create_nodes function to fix the warning.
  """
  
  alias XIAM.Hierarchy.NodeManager
  
  @doc """
  Implements the missing batch_create_nodes function.
  This creates multiple nodes at once by calling create_node for each one.
  """
  def batch_create_nodes(nodes_params) when is_list(nodes_params) do
    # Process each node parameter sequentially
    Enum.map(nodes_params, fn node_params ->
      NodeManager.create_node(node_params)
    end)
  end
end
