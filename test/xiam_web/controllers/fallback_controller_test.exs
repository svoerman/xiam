defmodule XIAMWeb.FallbackControllerTest do
  use XIAMWeb.ConnCase

  # Test the fallback controller directly
  test "handles not found errors", %{conn: conn} do
    # Call the fallback controller with a not_found error
    conn = XIAMWeb.FallbackController.call(conn, {:error, :not_found})
    
    # Assert correct status and response format
    assert conn.status == 404
    assert conn.resp_body =~ "Not Found"
  end

  test "handles validation errors from changeset", %{conn: conn} do
    # Create a changeset with an error
    changeset = Ecto.Changeset.change(%XIAM.Users.User{})
      |> Ecto.Changeset.add_error(:email, "is invalid")
      
    # Call the fallback controller with the changeset
    conn = XIAMWeb.FallbackController.call(conn, {:error, changeset})
    
    # Assert correct status
    assert conn.status == 422
    # Parse the response body as JSON to check for the actual structure
    response = Jason.decode!(conn.resp_body)
    assert response["errors"] != nil
  end

  test "handles unauthorized errors", %{conn: conn} do
    # Call the fallback controller with an unauthorized error
    conn = XIAMWeb.FallbackController.call(conn, {:error, :unauthorized})
    
    # Assert correct status
    assert conn.status == 403
    assert conn.resp_body =~ "Forbidden"
  end

  test "handles other error types", %{conn: conn} do
    # Call the fallback controller with a generic error
    conn = XIAMWeb.FallbackController.call(conn, {:error, "some internal error"})
    
    # Assert correct status
    assert conn.status == 500
    assert conn.resp_body =~ "error"
  end
end
