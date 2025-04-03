defmodule XIAMWeb.ErrorViewTest do
  use XIAMWeb.ConnCase, async: true

  # No imports needed for this test

  test "renders 403.html" do
    assert XIAMWeb.ErrorView.render("403.html", %{}) == "Forbidden"
  end

  test "renders 404.html" do
    assert XIAMWeb.ErrorView.render("404.html", %{}) == "Not Found"
  end

  test "renders 500.html" do
    assert XIAMWeb.ErrorView.render("500.html", %{}) == "Internal Server Error"
  end

  test "template_not_found/2 returns status message" do
    assert XIAMWeb.ErrorView.template_not_found("501.html", %{}) == "Not Implemented"
  end
end