defmodule XIAMWeb.SessionController do
  use Pow.Phoenix.Controller

  def after_sign_in_path(_conn, user) do
    # Preload the user's role and capabilities
    user = XIAM.Repo.preload(user, role: :capabilities)
    
    # Check if the user has the Administrator role with admin_access capability
    if user.role && 
       user.role.name == "Administrator" && 
       Enum.any?(user.role.capabilities, &(&1.name == "admin_access")) do
      # Redirect to admin panel for administrators
      "/admin"
    else
      # Default redirect for regular users
      "/"
    end
  end
end
