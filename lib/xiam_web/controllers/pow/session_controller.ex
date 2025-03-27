defmodule XIAMWeb.Pow.SessionController do
  use Pow.Phoenix.Controller

  alias Pow.Plug
  require Logger

  # Override create action from Pow.Phoenix.SessionController
  def create(conn, params) do
    conn
    |> Pow.Plug.authenticate_user(params)
    |> handle_authentication_result(params)
  end

  defp handle_authentication_result({:ok, conn}, _params) do
    user = Plug.current_user(conn)
    redirect_path = get_redirect_path_for_user(user)

    conn
    |> put_flash(:info, "Welcome back!")
    |> redirect(to: redirect_path)
  end

  defp handle_authentication_result({:error, conn}, params) do
    conn
    |> put_flash(:error, "Invalid email or password")
    |> render("new.html",
      errors: conn.assigns.changeset.errors,
      user_id_field: Pow.Ecto.Schema.user_id_field(Plug.fetch_config(conn)),
      params: params["user"],
      csrf_token: Plug.CSRFProtection.get_csrf_token()
    )
  end

  defp get_redirect_path_for_user(user) do
    user = XIAM.Repo.preload(user, role: :capabilities)

    if is_admin?(user) do
      Logger.info("Redirecting admin user #{user.email} to admin dashboard")
      "/admin"
    else
      "/"
    end
  end

  defp is_admin?(user) do
    user.role != nil &&
    user.role.name == "Administrator" &&
    Enum.any?(user.role.capabilities || [], &(&1.name == "admin_access"))
  end
end
