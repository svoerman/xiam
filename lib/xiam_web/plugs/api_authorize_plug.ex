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
    capability = Keyword.get(opts, :capability)
    %{capability: capability}
  end
  
  def init(capability) when is_binary(capability) or is_atom(capability) do
    %{capability: capability}
  end
  
  # Support for auth-only mode (no capability check, just authenticated)
  def init(nil), do: %{capability: nil}
  def init([]), do: %{capability: nil}
  
  def init(_), do: raise(ArgumentError, "capability must be a string, atom, or options keyword list")
  
  @doc """
  Checks if the user has the required capability.
  If not, returns 403 Forbidden.
  """
  def call(conn, %{capability: required_capability}) do
    case conn.assigns[:current_user] do
      nil ->
        AuthHelpers.unauthorized_response(conn, "Authentication required")
        
      user ->
        # If no capability is required, just check authentication
        if required_capability == nil do
          conn
        else
          # Convert atom to string if needed
          capability = if is_atom(required_capability), do: Atom.to_string(required_capability), else: required_capability
          
          if has_capability?(user, capability) do
            conn
          else
            AuthHelpers.forbidden_response(conn, "Insufficient permissions")
          end
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
