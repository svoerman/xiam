defmodule XIAMWeb.Pow.ControllerCallbacks do
  @moduledoc """
  Controller callbacks for Pow authentication.
  """
  use Pow.Extension.Phoenix.ControllerCallbacks.Base

  require Logger

  def before_respond(Pow.Phoenix.SessionController, :create, {:ok, conn}, _config) do
    user = Pow.Plug.current_user(conn)
    user = XIAM.Repo.preload(user, role: :capabilities)

    if is_admin?(user) do
      Logger.info("Admin user logged in: #{user.email}")
      
      {:ok, conn
      |> Phoenix.Controller.put_flash(:info, "Welcome to the admin panel!")
      |> Phoenix.Controller.redirect(to: "/admin")}
    else
      {:ok, conn}
    end
  end
  def before_respond(_controller, _action, results, _config) do
    # For any other controller/action, just pass through
    results
  end

  defp is_admin?(user) do
    user.role != nil && 
    user.role.name == "Administrator" && 
    Enum.any?(user.role.capabilities || [], &(&1.name == "admin_access"))
  end
end
