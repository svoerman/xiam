defmodule XIAMWeb.API.ProductController do
  use XIAMWeb, :controller
  alias Xiam.Rbac.AccessControl
  alias XIAMWeb.Plugs.APIAuthorizePlug

  # Apply authorization plugs with specific capabilities
  plug APIAuthorizePlug, :list_products when action in [:index]
  plug APIAuthorizePlug, :create_product when action in [:create]
  plug APIAuthorizePlug, :show_product when action in [:show]
  plug APIAuthorizePlug, :update_product when action in [:update]
  plug APIAuthorizePlug, :delete_product when action in [:delete]

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

  # Show a specific product
  def show(conn, %{"id" => id}) do
    case AccessControl.get_product(id) do
      nil -> send_resp(conn, :not_found, "")
      product -> json(conn, %{data: product})
    end
  end

  # Update a product
  def update(conn, %{"id" => id, "product_name" => product_name}) do
    case AccessControl.get_product(id) do
      nil -> send_resp(conn, :not_found, "")
      product ->
        case AccessControl.update_product(product, %{product_name: product_name}) do
          {:ok, prod} -> json(conn, %{data: prod})
          {:error, changeset} ->
            errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
              Enum.reduce(opts, msg, fn {key, value}, acc ->
                String.replace(acc, "%{#{key}}", to_string(value))
              end)
            end)
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: errors})
        end
    end
  end

  # Delete a product
  def delete(conn, %{"id" => id}) do
    case AccessControl.get_product(id) do
      nil -> send_resp(conn, :not_found, "")
      product ->
        {:ok, _} = AccessControl.delete_product(product)
        send_resp(conn, :no_content, "")
    end
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
