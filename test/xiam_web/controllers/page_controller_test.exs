defmodule XIAMWeb.PageControllerTest do
  use XIAMWeb.ConnCase

  test "GET /", %{conn: conn} do
    # Remove JSON accept header and use HTML instead for this test
    conn = 
      conn
      |> delete_req_header("accept")
      |> put_req_header("accept", "text/html")
      |> get(~p"/")
      
    assert html_response(conn, 200) =~ "XIAM Admin"
  end
end
