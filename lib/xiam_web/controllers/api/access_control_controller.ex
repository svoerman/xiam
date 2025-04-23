defmodule XIAMWeb.API.AccessControlController do
  use XIAMWeb, :controller
  alias Xiam.Rbac.AccessControl
  alias Xiam.Rbac
  alias XIAMWeb.Plugs.APIAuthorizePlug

  # Apply authorization plugs with specific capabilities
  plug APIAuthorizePlug, :manage_access when action in [:set_user_access]
  # Allow any authenticated user to view access (no specific capability required)
  plug APIAuthorizePlug, nil when action in [:get_user_access]
  # create_product and list_products seem to be handled by ProductController now, remove if redundant
  # plug APIAuthorizePlug, :manage_products when action in [:create_product]
  # plug APIAuthorizePlug, :view_products when action in [:list_products]
  plug APIAuthorizePlug, :manage_capabilities when action in [:create_capability]
  plug APIAuthorizePlug, :view_capabilities when action in [:get_product_capabilities]

  def set_user_access(conn, %{"user_id" => user_id, "entity_type" => entity_type, "entity_id" => entity_id, "role" => role}) do
    # Get role ID from role name
    role = Rbac.get_role_by_name(role)

    case AccessControl.set_user_access(%{
      user_id: user_id,
      entity_type: entity_type,
      entity_id: entity_id,
      role_id: role.id
    }) do
      {:ok, access} ->
        # Format the access entry for JSON response
        formatted_access = %{
          id: access.id,
          user_id: access.user_id,
          entity_type: access.entity_type,
          entity_id: access.entity_id,
          role_id: access.role_id
        }

        conn
        |> put_status(:ok)
        |> json(%{data: formatted_access})

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

  def get_user_access(conn, %{"user_id" => user_id}) do
    access_list = AccessControl.get_user_access(user_id)

    # Format the access entries for JSON response
    formatted_access = Enum.map(access_list, fn access ->
      %{
        id: access.id,
        user_id: access.user_id,
        entity_type: access.entity_type,
        entity_id: access.entity_id,
        role_id: access.role_id
      }
    end)

    conn
    |> put_status(:ok)
    |> json(%{data: formatted_access})
  end

  def create_product(conn, %{"product_name" => product_name}) do
    case AccessControl.create_product(%{product_name: product_name}) do
      {:ok, product} ->
        conn
        |> put_status(:created)
        |> json(%{data: product})

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

  def list_products(conn, _params) do
    products = AccessControl.list_products()
    json(conn, %{data: products})
  end

  def create_capability(conn, %{"product_id" => product_id, "capability_name" => capability_name, "description" => description}) do
    case AccessControl.create_capability(%{
      product_id: product_id,
      name: capability_name,
      description: description
    }) do
      {:ok, capability} ->
        conn
        |> put_status(:created)
        |> json(%{data: capability})

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

  def get_product_capabilities(conn, %{"product_id" => product_id}) do
    capabilities = AccessControl.get_product_capabilities(product_id)
    json(conn, %{data: capabilities})
  end
end
