defmodule XIAMWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  Provides standard handling for error responses from controllers.
  """
  use XIAMWeb, :controller

  @doc "Translates controller error responses"
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: XIAMWeb.ErrorJSON)
    |> render("422.json", changeset: changeset)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: XIAMWeb.ErrorJSON)
    |> render("404.json")
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:forbidden)
    |> put_view(json: XIAMWeb.ErrorJSON)
    |> render("403.json")
  end

  def call(conn, {:error, error}) do
    conn
    |> put_status(:internal_server_error)
    |> put_view(json: XIAMWeb.ErrorJSON)
    |> render("500.json", error: error)
  end
end
