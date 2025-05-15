defmodule XIAMWeb.API.ConsentsControllerTest do
  use XIAMWeb.ConnCase

  alias XIAM.Users.User
  alias XIAM.Consent.ConsentRecord
  alias XIAM.Repo
  alias XIAM.Auth.JWT
  alias XIAM.Rbac.ProductContext

  setup %{conn: conn} do
    # Generate a unique timestamp for this test run
    timestamp = System.system_time(:second)

    # Clean up existing test data
    import Ecto.Query
    Repo.delete_all(from p in Xiam.Rbac.Product, where: like(p.product_name, "%Test_Consent_Product_%"))
    Repo.delete_all(from r in Xiam.Rbac.Role, where: like(r.name, "%Consent_Admin_%"))
    Repo.delete_all(from u in User, where: like(u.email, "%api_consent_test%"))
    # Clean up capabilities too
    Repo.delete_all(from c in Xiam.Rbac.Capability, where: like(c.name, "%_consents%"))

    # Create a test user with admin capability
    email = "api_consent_test_#{timestamp}@example.com"
    {:ok, user} = %User{}
      |> User.pow_changeset(%{
        email: email,
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Repo.insert()

    # Create a role with necessary capabilities
    role_name = "Consent_Admin_#{timestamp}"
    {:ok, role} = Xiam.Rbac.Role.changeset(%Xiam.Rbac.Role{}, %{
      name: role_name,
      description: "Role for testing consent API"
    })
    |> Repo.insert()

    # Create a product to associate capabilities with
    product_name = "Test_Consent_Product_#{timestamp}"
    {:ok, product} = ProductContext.create_product(%{
      product_name: product_name,
      description: "Test product for API tests"
    })

    # Add capabilities (including delete_consent), associating with product
    capabilities_to_create = [
      %{product_id: product.id, name: "manage_consents", description: "Can manage consents"},
      %{product_id: product.id, name: "list_consents", description: "Can list consents"},
      %{product_id: product.id, name: "create_consent", description: "Can create consents"},
      %{product_id: product.id, name: "update_consent", description: "Can update consents"},
      %{product_id: product.id, name: "delete_consent", description: "Can delete consents"},
      %{product_id: product.id, name: "admin_consents", description: "Admin capabilities for consents"},
      %{product_id: product.id, name: "auth", description: "Basic auth capabilities"}
    ]

    capabilities = Enum.map(capabilities_to_create, fn cap_attrs ->
      {:ok, cap} = Xiam.Rbac.create_capability(cap_attrs)
      cap
    end)

    # Associate capabilities with role using put_assoc
    {:ok, role} = role
      |> Repo.preload(:capabilities) # Preload existing if needed, though likely empty
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:capabilities, capabilities)
      |> Repo.update()

    # Assign role to user
    {:ok, user} = user
      |> User.role_changeset(%{role_id: role.id})
      |> Repo.update()

    # Reload user with role and capabilities
    user = user |> Repo.preload(role: :capabilities)

    # Generate a token for authentication
    {:ok, token, _claims} = JWT.generate_token(user)

    # Create a test consent record
    {:ok, consent} = %ConsentRecord{
      user_id: user.id,
      consent_type: "marketing",
      consent_given: true,
      ip_address: "127.0.0.1",
      user_agent: "Test Browser"
    }
    |> Repo.insert()

    conn = conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")

    {:ok, conn: conn, user: user, consent: consent}
  end

  describe "consent records API" do
    test "GET /api/consents returns user's consent records", %{conn: conn, user: _user, consent: consent} do
      conn = get(conn, ~p"/api/v1/consents")

      assert %{"consents" => consents} = json_response(conn, 200)
      assert length(consents) >= 1
      assert Enum.any?(consents, fn c -> c["id"] == consent.id end)
    end

    test "GET /api/consents with filters returns filtered results", %{conn: conn, user: _user} do
      conn = get(conn, ~p"/api/v1/consents?consent_type=marketing")

      assert %{"consents" => consents} = json_response(conn, 200)
      assert length(consents) >= 1
      assert Enum.all?(consents, fn c -> c["consent_type"] == "marketing" end)
    end

    test "POST /api/consents creates a new consent record", %{conn: conn} do
      consent_params = %{
        consent: %{
          consent_type: "analytics",
          consent_given: true,
          data_source: "API test"
        }
      }

      # Manually set remote_ip for the test connection
      conn = %{conn | remote_ip: {127, 0, 0, 1}}

      conn = post(conn, ~p"/api/v1/consents", consent_params)

      assert %{"consent" => consent} = json_response(conn, 200)
      assert consent["consent_type"] == "analytics"
      assert consent["consent_given"] == true
    end

    test "PUT /api/consents/:id updates a consent record", %{conn: conn, consent: consent} do
      update_params = %{
        consent: %{
          consent_given: false
        }
      }

      conn = put(conn, ~p"/api/v1/consents/#{consent.id}", update_params)

      assert %{"consent" => updated_consent} = json_response(conn, 200)
      assert updated_consent["id"] == consent.id
      assert updated_consent["consent_given"] == false
    end

    test "DELETE /api/consents/:id revokes a consent record", %{conn: conn, consent: consent} do
      conn = delete(conn, ~p"/api/v1/consents/#{consent.id}")

      assert response(conn, 204)

      # Verify the consent was actually revoked
      revoked_consent = Repo.get!(ConsentRecord, consent.id)
      assert revoked_consent.consent_given == false
      assert revoked_consent.revoked_at != nil
    end
  end
end
