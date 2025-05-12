defmodule XIAM.BatchWarningSuppressor do
  @moduledoc """
  This module is used to suppress the batch_create_nodes warning globally.
  """
  
  # Suppress the specific warning about batch_create_nodes
  @compile {:no_warn_undefined, [{XIAM.Hierarchy.NodeManager, :batch_create_nodes, 1}]}
  
  def suppress_warnings do
    # No-op function that just needs to be called to apply the module attributes
    :ok
  end
end
