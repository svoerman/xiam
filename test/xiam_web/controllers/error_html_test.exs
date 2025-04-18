defmodule XIAMWeb.ErrorHTMLTest do
  use XIAMWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template

  test "renders 404.html" do
    assert render_to_string(XIAMWeb.ErrorHTML, "404", "html", []) == "Not Found"
  end

  test "renders 500.html" do
    assert render_to_string(XIAMWeb.ErrorHTML, "500", "html", []) == "Internal Server Error"
  end
  
  test "renders 403.html" do
    assert render_to_string(XIAMWeb.ErrorHTML, "403", "html", []) == "Forbidden"
  end

  test "handles other status codes" do
    assert render_to_string(XIAMWeb.ErrorHTML, "422", "html", []) == "Unprocessable Entity"
  end
end
