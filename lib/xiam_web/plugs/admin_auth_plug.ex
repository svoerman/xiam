defmodule XIAMWeb.Plugs.AdminAuthPlug do
  @moduledoc """
  A plug to protect admin routes.
  Ensures that the current user has admin privileges.
  """

  import Plug.Conn
  import Phoenix.Controller

  alias XIAMWeb.Plugs.AuthHelpers

  def init(opts), do: opts

  def call(conn, _opts) do
    current_user = Pow.Plug.current_user(conn)

    if AuthHelpers.has_admin_privileges?(current_user) do
      conn
    else
      conn
      |> put_flash(:error, "You do not have permission to access this area.")
      |> redirect(to: "/")
      |> halt()
    end
  end
end
