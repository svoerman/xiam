defmodule XIAMWeb.API.ProductController do
  use XIAMWeb, :controller
  alias Xiam.Rbac.AccessControl

  def index(conn, _params) do
    products = AccessControl.list_products()
    json(conn, %{data: products})
  end

  def create(conn, %{"product_name" => product_name}) do
    case AccessControl.create_product(%{product_name: product_name}) do
      {:ok, product} ->
        conn
        |> put_status(:created)
        |> json(%{data: product})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset})
    end
  end
end
