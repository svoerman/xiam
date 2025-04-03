defmodule XIAMWeb.ErrorJSONTest do
  use XIAMWeb.ConnCase, async: true

  test "renders 404" do
    assert XIAMWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert XIAMWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
  
  test "renders 403" do
    assert XIAMWeb.ErrorJSON.render("403.json", %{}) == %{errors: %{detail: "Forbidden"}}
  end

  test "renders 422" do
    assert XIAMWeb.ErrorJSON.render("422.json", %{}) == %{errors: %{detail: "Unprocessable Entity"}}
  end
end
