defmodule XIAM.CompilerSettings do
  @moduledoc """
  This module provides global compiler settings to suppress known warnings.
  """
  
  # Suppress warnings for batch_create_nodes/1
  @compile {:nowarn_undefined, [{XIAM.Hierarchy.NodeManager, :batch_create_nodes, 1}]}
  
  def apply_settings do
    # This is just a placeholder function
    :ok
  end
end
