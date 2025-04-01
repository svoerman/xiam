defmodule XIAMWeb.API.ConsentsControllerTest do
  use XIAMWeb.ConnCase

  alias XIAM.Users.User
  alias XIAM.Consent.ConsentRecord
  alias XIAM.Repo
  alias XIAM.Auth.JWT

  setup %{conn: conn} do
    # Create a test user with admin capability
    {:ok, user} = %User{}
      |> User.pow_changeset(%{
        email: "api_consent_test@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Repo.insert()

    # Create a role with necessary capabilities
    {:ok, role} = Xiam.Rbac.Role.changeset(%Xiam.Rbac.Role{}, %{
      name: "Consent Admin",
      description: "Role for testing consent API"
    })
    |> Repo.insert()

    # Create a product to associate capabilities with
    {:ok, product} = Xiam.Rbac.Product.changeset(%Xiam.Rbac.Product{}, %{
      product_name: "Test Product",
      description: "Test product for API tests"
    }) |> Repo.insert()
    
    # Add capabilities to the role (with correct product association)
    capabilities = [
      %Xiam.Rbac.Capability{name: "manage_consents", description: "Can manage consents", product_id: product.id},
      %Xiam.Rbac.Capability{name: "read_consents", description: "Can read consents", product_id: product.id},
      %Xiam.Rbac.Capability{name: "admin_consents", description: "Admin capabilities for consents", product_id: product.id}
    ]
    
    # Insert capabilities
    capability_ids = Enum.map(capabilities, fn cap -> 
      {:ok, cap} = Repo.insert(cap)
      cap.id
    end)
    
    # Get the capabilities
    capabilities = Enum.map(capability_ids, &Xiam.Rbac.Capability.get_capability!/1)
    
    # Associate capabilities with role
    role
    |> Repo.preload(:capabilities)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:capabilities, capabilities)
    |> Repo.update!()

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
      conn = get(conn, ~p"/api/consents")

      assert %{"consents" => consents} = json_response(conn, 200)
      assert length(consents) >= 1
      assert Enum.any?(consents, fn c -> c["id"] == consent.id end)
    end

    test "GET /api/consents with filters returns filtered results", %{conn: conn, user: _user} do
      conn = get(conn, ~p"/api/consents?consent_type=marketing")

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

      conn = post(conn, ~p"/api/consents", consent_params)

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

      conn = put(conn, ~p"/api/consents/#{consent.id}", update_params)

      assert %{"consent" => updated_consent} = json_response(conn, 200)
      assert updated_consent["id"] == consent.id
      assert updated_consent["consent_given"] == false
    end

    test "DELETE /api/consents/:id revokes a consent record", %{conn: conn, consent: consent} do
      conn = delete(conn, ~p"/api/consents/#{consent.id}")

      assert response(conn, 204)

      # Verify the consent was actually revoked
      revoked_consent = Repo.get!(ConsentRecord, consent.id)
      assert revoked_consent.consent_given == false
      assert revoked_consent.revoked_at != nil
    end
  end
end