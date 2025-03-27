defmodule XIAMWeb.ErrorView do
  use XIAMWeb, :html

  # If you want to customize a particular status code,
  # you may add your own clauses, such as:
  def template_not_found(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end

  def render("403.html", _assigns) do
    "Forbidden"
  end

  def render("404.html", _assigns) do
    "Not Found"
  end

  def render("500.html", _assigns) do
    "Internal Server Error"
  end
end
