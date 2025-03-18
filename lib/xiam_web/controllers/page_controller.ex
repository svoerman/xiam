defmodule XIAMWeb.PageController do
  use XIAMWeb, :controller

  def home(conn, _params) do
    # Use the standard app layout for consistency with shadcn UI
    render(conn, :home)
  end
end
