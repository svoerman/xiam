defmodule XIAMWeb.Admin.ProductsLive do
  use XIAMWeb, :live_view

  import XIAMWeb.Components.UI.Button
  import XIAMWeb.Components.UI.Modal
  import XIAMWeb.CoreComponents, except: [button: 1, modal: 1]
  import XIAMWeb.Components.UI

  alias Xiam.Rbac.AccessControl
  alias Xiam.Rbac.Product
  alias Xiam.Rbac.Capability
  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, _session, socket) do
    products = AccessControl.list_products()
    product_changeset = Product.changeset(%Product{}, %{})
    capability_changeset = Capability.changeset(%Capability{}, %{})

    socket = assign(socket,
      page_title: "Products & Capabilities",
      products: products,
      selected_product: nil,
      product_changeset: product_changeset,
      capability_changeset: capability_changeset,
      form_mode: nil,
      show_modal: false,
      show_capability_modal: false
    )

    {:ok, socket}
  end

  @impl true
  def handle_event("show_new_product_modal", _params, socket) do
    product_changeset = Product.changeset(%Product{}, %{})
    {:noreply, assign(socket,
      show_modal: true,
      form_mode: :new_product,
      selected_product: nil,
      product_changeset: product_changeset
    )}
  end

  def handle_event("show_edit_product_modal", %{"id" => id}, socket) do
    case AccessControl.get_product(id) do
      nil ->
        {:noreply, socket |> put_flash(:error, "Product not found")}
      product ->
        product_changeset = Product.changeset(product, %{
          product_name: product.product_name,
          description: product.description
        })
        {:noreply, assign(socket,
          show_modal: true,
          form_mode: :edit_product,
          selected_product: product,
          product_changeset: product_changeset
        )}
    end
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket,
      show_modal: false,
      show_capability_modal: false,
      form_mode: nil,
      selected_product: nil,
      selected_capability: nil,
      product_changeset: nil,
      capability_changeset: nil
    )}
  end

  def handle_event("save_product", %{"product" => product_params}, socket) do
    case socket.assigns.form_mode do
      :new_product ->
        case AccessControl.create_product(product_params) do
          {:ok, _product} ->
            products = AccessControl.list_products()
            product_changeset = Product.changeset(%Product{}, %{})

            {:noreply, socket
              |> assign(products: products, show_modal: false, product_changeset: product_changeset)
              |> put_flash(:info, "Product created successfully")}

          {:error, changeset} ->
            {:noreply, assign(socket, product_changeset: changeset)}
        end

      :edit_product ->
        case socket.assigns.selected_product do
          nil ->
            {:noreply, socket |> put_flash(:error, "No product selected")}
          product ->
            case AccessControl.update_product(product, product_params) do
              {:ok, _product} ->
                products = AccessControl.list_products()
                product_changeset = Product.changeset(%Product{}, %{})

                {:noreply, socket
                  |> assign(products: products, show_modal: false, product_changeset: product_changeset)
                  |> put_flash(:info, "Product updated successfully")}

              {:error, changeset} ->
                {:noreply, assign(socket, product_changeset: changeset)}
            end
        end

      _other ->
        {:noreply, socket |> put_flash(:error, "Invalid form mode")}
    end
  end

  def handle_event("delete_product", %{"id" => id}, socket) do
    case AccessControl.get_product(id) do
      nil ->
        {:noreply, socket |> put_flash(:error, "Product not found")}
      product ->
        case AccessControl.delete_product(product) do
          {:ok, _} ->
            products = AccessControl.list_products()
            {:noreply, socket
              |> assign(products: products)
              |> put_flash(:info, "Product deleted successfully")}

          {:error, _changeset} ->
            {:noreply, socket |> put_flash(:error, "Failed to delete product. It may have associated capabilities.")}
        end
    end
  end

  def handle_event("show_new_capability_modal", %{"product_id" => product_id}, socket) do
    case AccessControl.get_product(product_id) do
      nil ->
        {:noreply, socket |> put_flash(:error, "Product not found")}
      product ->
        capability_changeset = Capability.changeset(%Capability{}, %{})
        {:noreply, assign(socket,
          show_capability_modal: true,
          form_mode: :new_capability,
          selected_product: product,
          capability_changeset: capability_changeset
        )}
    end
  end

  def handle_event("show_edit_capability_modal", %{"id" => id}, socket) do
    case AccessControl.get_capability(id) do
      nil ->
        {:noreply, socket |> put_flash(:error, "Capability not found")}
      capability ->
        capability_changeset = Capability.changeset(capability, %{
          name: capability.name,
          description: capability.description
        })
        {:noreply, assign(socket,
          show_capability_modal: true,
          form_mode: :edit_capability,
          selected_capability: capability,
          capability_changeset: capability_changeset
        )}
    end
  end

  def handle_event("save_capability", %{"capability" => capability_params}, socket) do
    case socket.assigns.form_mode do
      :new_capability ->
        case AccessControl.create_capability(capability_params) do
          {:ok, _capability} ->
            products = AccessControl.list_products()
            capability_changeset = Capability.changeset(%Capability{}, %{})

            {:noreply, socket
              |> assign(products: products, show_capability_modal: false, capability_changeset: capability_changeset)
              |> put_flash(:info, "Capability created successfully")}

          {:error, changeset} ->
            {:noreply, assign(socket, capability_changeset: changeset)}
        end

      :edit_capability ->
        case socket.assigns.selected_capability do
          nil ->
            {:noreply, socket |> put_flash(:error, "No capability selected")}
          capability ->
            case AccessControl.update_capability(capability, capability_params) do
              {:ok, _capability} ->
                products = AccessControl.list_products()
                capability_changeset = Capability.changeset(%Capability{}, %{})

                {:noreply, socket
                  |> assign(products: products, show_capability_modal: false, capability_changeset: capability_changeset)
                  |> put_flash(:info, "Capability updated successfully")}

              {:error, changeset} ->
                {:noreply, assign(socket, capability_changeset: changeset)}
            end
        end

      _other ->
        {:noreply, socket |> put_flash(:error, "Invalid form mode")}
    end
  end

  def handle_event("delete_capability", %{"id" => id}, socket) do
    case AccessControl.get_capability(id) do
      nil ->
        {:noreply, socket |> put_flash(:error, "Capability not found")}
      capability ->
        case AccessControl.delete_capability(capability) do
          {:ok, _} ->
            products = AccessControl.list_products()
            {:noreply, socket
              |> assign(products: products)
              |> put_flash(:info, "Capability deleted successfully")}

          {:error, _changeset} ->
            {:noreply, socket |> put_flash(:error, "Failed to delete capability. It may be in use.")}
        end
    end
  end
end
