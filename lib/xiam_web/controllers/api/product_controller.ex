defmodule XIAMWeb.API.ProductController do
  use XIAMWeb, :controller
  alias Xiam.Rbac.AccessControl

  def index(conn, _params) do
    products = AccessControl.list_products()
    render(conn, :index, products: products)
  end

  def create(conn, %{"product_name" => product_name}) do
    case AccessControl.create_product(%{product_name: product_name}) do
      {:ok, product} ->
        conn
        |> put_status(:created)
        |> render(:show, product: product)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset_errors(changeset)})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: %{product_name: ["can't be blank"]}})
  end

  # Helper function to format changeset errors for JSON response
  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
