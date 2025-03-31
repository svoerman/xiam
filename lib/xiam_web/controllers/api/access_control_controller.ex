defmodule XIAMWeb.API.AccessControlController do
  use XIAMWeb, :controller
  alias Xiam.Rbac.AccessControl

  def set_user_access(conn, %{"user_id" => user_id, "entity_type" => entity_type, "entity_id" => entity_id, "role" => role}) do
    case AccessControl.set_user_access(%{
      user_id: user_id,
      entity_type: entity_type,
      entity_id: entity_id,
      role: role
    }) do
      {:ok, access} ->
        conn
        |> put_status(:ok)
        |> json(%{data: access})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset})
    end
  end

  def get_user_access(conn, %{"user_id" => user_id}) do
    access = AccessControl.get_user_access(user_id)
    json(conn, %{data: access})
  end

  def create_product(conn, %{"product_name" => product_name}) do
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

  def list_products(conn, _params) do
    products = AccessControl.list_products()
    json(conn, %{data: products})
  end

  def create_capability(conn, %{"product_id" => product_id, "capability_name" => capability_name, "description" => description}) do
    case AccessControl.create_capability(%{
      product_id: product_id,
      capability_name: capability_name,
      description: description
    }) do
      {:ok, capability} ->
        conn
        |> put_status(:created)
        |> json(%{data: capability})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset})
    end
  end

  def get_product_capabilities(conn, %{"product_id" => product_id}) do
    capabilities = AccessControl.get_product_capabilities(product_id)
    json(conn, %{data: capabilities})
  end
end
