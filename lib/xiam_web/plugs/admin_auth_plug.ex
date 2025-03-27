defmodule XIAMWeb.Plugs.AdminAuthPlug do
  @moduledoc """
  A plug to protect admin routes.
  Ensures that the current user has admin privileges.
  """

  import Plug.Conn
  import Phoenix.Controller

  #alias XIAM.Users.User
  #alias XIAM.RBAC.Role
  #alias XIAM.RBAC.Capability
  alias XIAM.Repo

  def init(opts), do: opts

  def call(conn, _opts) do
    current_user = Pow.Plug.current_user(conn)

    if has_admin_privileges?(current_user) do
      conn
    else
      conn
      |> put_flash(:error, "You do not have permission to access this area.")
      |> redirect(to: "/")
      |> halt()
    end
  end

  # Checks if the current user has admin capabilities
  defp has_admin_privileges?(nil), do: false
  defp has_admin_privileges?(user) do
    user = user |> Repo.preload(role: :capabilities)

    # User has admin privileges if:
    # 1. They have a role with admin capability
    # 2. They have been specifically granted admin access
    case user.role do
      nil -> false
      role ->
        Enum.any?(role.capabilities, fn capability ->
          capability.name == "admin_access"
        end)
    end
  end
end
