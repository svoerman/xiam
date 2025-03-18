defmodule XIAMWeb.Plugs.AdminRedirectPlug do
  @moduledoc """
  Plug to redirect admin users to the admin dashboard after login.
  """
  import Plug.Conn
  import Phoenix.Controller
  alias XIAM.Repo
  require Logger
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    current_user = Pow.Plug.current_user(conn)
    
    # Only run checks on homepage access
    if conn.request_path == "/" && current_user do
      Logger.info("Admin redirect check for user: #{current_user.email}")
      
      # Check if user has admin role and permissions
      user_with_data = Repo.preload(current_user, role: :capabilities)
      
      if is_admin?(user_with_data) do
        Logger.info("Redirecting admin user to admin dashboard")
        
        conn
        |> put_flash(:info, "Welcome to the admin dashboard!")
        |> redirect(to: "/admin")
        |> halt()
      else
        conn
      end
    else
      conn
    end
  end
  
  # Checks if user has admin role with required capabilities
  defp is_admin?(user) do
    if user.role do
      capabilities = user.role.capabilities || []
      has_admin_access = Enum.any?(capabilities, &(&1.name == "admin_access"))
      
      Logger.info("User role: #{user.role.name}, has admin_access: #{has_admin_access}")
      
      user.role.name == "Administrator" && has_admin_access
    else
      Logger.info("User has no role assigned")
      false
    end
  end
end
