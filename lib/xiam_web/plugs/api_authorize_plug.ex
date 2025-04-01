defmodule XIAMWeb.Plugs.APIAuthorizePlug do
  @moduledoc """
  Plug for API authorization using capabilities.
  Checks if the authenticated user has the required capability to access the endpoint.
  """
  
  alias XIAMWeb.Plugs.AuthHelpers
  
  @doc """
  Initialize the plug with the required capability or options map.
  """
  def init(opts) when is_list(opts) do
    # Support for options list with capability key
    case Keyword.get(opts, :capability) do
      nil -> raise ArgumentError, "capability must be specified in options"
      capability -> %{capability: capability}
    end
  end
  
  def init(capability) when is_binary(capability) or is_atom(capability) do
    %{capability: capability}
  end
  
  def init(_), do: raise(ArgumentError, "capability must be a string, atom, or options keyword list")
  
  @doc """
  Checks if the user has the required capability.
  If not, returns 403 Forbidden.
  """
  def call(conn, %{capability: required_capability}) do
    required_capability = if is_atom(required_capability), do: Atom.to_string(required_capability), else: required_capability
    
    case conn.assigns[:current_user] do
      nil ->
        AuthHelpers.unauthorized_response(conn, "Authentication required")
        
      user ->
        if has_capability?(user, required_capability) do
          conn
        else
          AuthHelpers.forbidden_response(conn, "Insufficient permissions")
        end
    end
  end
  
  @doc """
  Checks if a user has a specific capability based on their role.
  Delegates to AuthHelpers for centralized authorization logic.
  """
  def has_capability?(user, required_capability) do
    AuthHelpers.has_capability?(user, required_capability)
  end
end
