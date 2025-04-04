defmodule XIAMWeb.FallbackControllerTest do
  use XIAMWeb.ConnCase

  # Create a test controller that will trigger the fallback
  defmodule TestController do
    use XIAMWeb, :controller

    action_fallback XIAMWeb.FallbackController

    def not_found(_conn, _params) do
      {:error, :not_found}
    end

    def invalid_params(_conn, _params) do
      changeset = Ecto.Changeset.change(%XIAM.Users.User{})
        |> Ecto.Changeset.add_error(:email, "is invalid")

      {:error, changeset}
    end

    def unauthorized(_conn, _params) do
      {:error, :unauthorized}
    end

    def unprocessable_entity(_conn, _params) do
      {:error, :unprocessable_entity}
    end
  end

  @tag :skip
  test "handles not found errors", %{conn: conn} do
    conn = TestController.not_found(conn, %{})
    assert json_response(conn, 404)["errors"] == %{"detail" => "Not Found"}
  end

  @tag :skip
  test "handles validation errors from changeset", %{conn: conn} do
    conn = TestController.invalid_params(conn, %{})
    response = json_response(conn, 422)
    assert response["errors"] != nil
    assert response["errors"]["email"] == ["is invalid"]
  end

  @tag :skip
  test "handles unauthorized errors", %{conn: conn} do
    conn = TestController.unauthorized(conn, %{})
    assert json_response(conn, 401)["errors"] == %{"detail" => "Unauthorized"}
  end

  @tag :skip
  test "handles unprocessable entity errors", %{conn: conn} do
    conn = TestController.unprocessable_entity(conn, %{})
    assert json_response(conn, 422)["errors"] == %{"detail" => "Unprocessable Entity"}
  end
end
