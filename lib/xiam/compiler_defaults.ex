defmodule XIAM.CompilerDefaults do
  @moduledoc """
  This module defines compiler defaults and options to suppress known warnings.
  These are warnings that we have explicitly decided are acceptable.
  """
  
  # Add the batch_create_nodes warning to the no_warn list
  @compile {:no_warn_undefined, [{XIAM.Hierarchy.NodeManager, :batch_create_nodes, 1}]}
  
  def configure_compiler do
    # This is a no-op function that just needs to be required
    # to apply the compiler attributes
    :ok
  end
end
