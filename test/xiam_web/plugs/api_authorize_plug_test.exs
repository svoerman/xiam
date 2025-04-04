defmodule XIAMWeb.Plugs.APIAuthorizePlugTest do
  use XIAMWeb.ConnCase, async: true

  alias XIAMWeb.Plugs.APIAuthorizePlug
  alias Xiam.Rbac.{Role, Capability, Product}

  @capability "test.capability"

  setup do
    # First create a product
    {:ok, product} =
      Product.changeset(%Product{}, %{
        product_name: "test_product",
        description: "Test product"
      })
      |> XIAM.Repo.insert()

    # Then create the capability
    {:ok, capability} =
      Capability.changeset(%Capability{}, %{
        name: @capability,
        description: "Test capability",
        product_id: product.id
      })
      |> XIAM.Repo.insert()

    # Then create the role with the capability
    {:ok, role} =
      Role.create_role_with_capabilities(
        %{
          name: "test_role",
          description: "Test role"
        },
        [capability.id]
      )

    {:ok, role: role}
  end

  describe "APIAuthorizePlug authorization" do
    test "accepts requests when user has required capability", %{conn: conn, role: role} do
      conn =
        conn
        |> assign(:current_user, %{role: role})
        |> APIAuthorizePlug.call(%{capability: @capability})

      refute conn.halted
    end

    test "accepts requests when user has required capability in list", %{conn: conn, role: role} do
      conn =
        conn
        |> assign(:current_user, %{role: role})
        |> APIAuthorizePlug.call(%{capability: [@capability]})

      refute conn.halted
    end

    test "accepts requests when user has one of required capabilities", %{conn: conn, role: role} do
      conn =
        conn
        |> assign(:current_user, %{role: role})
        |> APIAuthorizePlug.call(%{capability: [@capability, "other.capability"]})

      refute conn.halted
    end

    test "rejects requests when user doesn't have required capability", %{conn: conn, role: role} do
      conn =
        conn
        |> assign(:current_user, %{role: role})
        |> APIAuthorizePlug.call(%{capability: "other.capability"})

      assert conn.halted
      assert conn.status == 403
      assert Jason.decode!(conn.resp_body)["error"] =~ "Access forbidden: Missing required capability"
    end

    test "rejects requests when user doesn't have any of required capabilities", %{
      conn: conn,
      role: role
    } do
      conn =
        conn
        |> assign(:current_user, %{role: role})
        |> APIAuthorizePlug.call(%{capability: ["other.capability", "another.capability"]})

      assert conn.halted
      assert conn.status == 403
      assert Jason.decode!(conn.resp_body)["error"] =~ "Access forbidden: Missing required capability"
    end

    test "rejects requests when user has no role", %{conn: conn} do
      conn =
        conn
        |> assign(:current_user, %{role: nil})
        |> APIAuthorizePlug.call(%{capability: @capability})

      assert conn.halted
      assert conn.status == 403
      assert Jason.decode!(conn.resp_body)["error"] =~ "Access forbidden: Missing required capability"
    end

    test "rejects requests when user is not assigned", %{conn: conn} do
      conn = APIAuthorizePlug.call(conn, %{capability: @capability})

      assert conn.halted
      assert conn.status == 401
      assert Jason.decode!(conn.resp_body)["error"] =~ "Authentication required"
    end
  end
end
