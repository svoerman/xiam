defmodule XIAMWeb.ErrorView do
  use Phoenix.Template,
    root: "lib/xiam_web/controllers/error_html",
    namespace: XIAMWeb

  # If you want to customize a particular status code,
  # you may add a clause like:
  #
  # def template_not_found("404.html", _assigns) do
  #   "Page not found"
  # end

  def template_not_found(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end

  def render("404.html", assigns) do
    render("any.html", assigns)
  end

  def render("500.html", assigns) do
    render("any.html", assigns)
  end

  def render("any.html", assigns) do
    Phoenix.Template.render_to_iodata("any.html", "ErrorView", assigns, [])
  end
end
