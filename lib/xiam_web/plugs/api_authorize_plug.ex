defmodule XIAMWeb.Plugs.APIAuthorizePlug do
  @moduledoc """
  Plug for API authorization using capabilities.
  Checks if the authenticated user has the required capability to access the endpoint.
  """
  
  import Plug.Conn
  import Phoenix.Controller
  
  @doc """
  Initialize the plug with the required capability.
  """
  def init(capability) when is_binary(capability) or is_atom(capability), do: capability
  def init(_), do: raise(ArgumentError, "capability must be a string or atom")
  
  @doc """
  Checks if the user has the required capability.
  If not, returns 403 Forbidden.
  """
  def call(conn, required_capability) do
    required_capability = if is_atom(required_capability), do: Atom.to_string(required_capability), else: required_capability
    
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})
        |> halt()
        
      user ->
        if has_capability?(user, required_capability) do
          conn
        else
          conn
          |> put_status(:forbidden)
          |> json(%{error: "Insufficient permissions"})
          |> halt()
        end
    end
  end
  
  @doc """
  Checks if a user has a specific capability based on their role.
  This function is public so it can be called from controllers.
  """
  def has_capability?(user, required_capability) do
    case user.role do
      nil -> false
      role ->
        Enum.any?(role.capabilities, fn capability -> 
          capability.name == required_capability
        end)
    end
  end
end
