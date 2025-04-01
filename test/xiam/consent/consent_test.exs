defmodule XIAM.ConsentTest do
  use XIAM.DataCase

  alias XIAM.Consent
  alias XIAM.Consent.ConsentRecord
  alias XIAM.Users.User
  alias XIAM.Repo

  # Mock connection for tests
  defmodule MockConn do
    defstruct remote_ip: {127, 0, 0, 1}, 
              req_headers: [{"user-agent", "Test Browser"}]
  end

  describe "consent records" do
    setup do
      # Create a test user
      {:ok, user} = %User{}
        |> User.pow_changeset(%{
          email: "consent_test@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })
        |> Repo.insert()

      # Create connection mock
      conn = %MockConn{}

      {:ok, user: user, conn: conn}
    end

    test "create_consent_record/3 creates a valid consent record", %{user: user, conn: conn} do
      attrs = %{
        "consent_type" => "marketing",
        "consent_given" => true,
        "ip_address" => "127.0.0.1",
        "user_agent" => "Test Browser"
      }

      assert {:ok, %ConsentRecord{} = consent} = Consent.create_consent_record(attrs, user, conn)
      assert consent.user_id == user.id
      assert consent.consent_type == "marketing"
      assert consent.consent_given == true
      assert consent.ip_address == "127.0.0.1"
      assert consent.user_agent == "Test Browser"
    end

    test "get_consent_record!/1 retrieves a consent record", %{user: user, conn: conn} do
      attrs = %{
        "consent_type" => "marketing",
        "consent_given" => true,
        "ip_address" => "127.0.0.1",
        "user_agent" => "Test Browser"
      }

      {:ok, %ConsentRecord{} = created_consent} = Consent.create_consent_record(attrs, user, conn)
      retrieved_consent = Consent.get_consent_record!(created_consent.id)
      assert retrieved_consent.id == created_consent.id
      assert retrieved_consent.consent_type == "marketing"
    end

    test "list_consent_records/2 returns filtered records", %{user: user, conn: conn} do
      # Create multiple consent records
      marketing_attrs = %{
        "consent_type" => "marketing",
        "consent_given" => true,
        "ip_address" => "127.0.0.1",
        "user_agent" => "Test Browser"
      }
      Consent.create_consent_record(marketing_attrs, user, conn)

      analytics_attrs = %{
        "consent_type" => "analytics",
        "consent_given" => false,
        "ip_address" => "127.0.0.1",
        "user_agent" => "Test Browser"
      }
      Consent.create_consent_record(analytics_attrs, user, conn)

      # Test filtering by user_id
      page = Consent.list_consent_records(%{user_id: user.id}, %{page: 1, per_page: 10})
      assert length(page.entries) >= 2

      # Test filtering by consent_type
      page = Consent.list_consent_records(%{consent_type: "marketing"}, %{page: 1, per_page: 10})
      assert length(page.entries) >= 1
      assert Enum.all?(page.entries, fn c -> c.consent_type == "marketing" end)

      # Test filtering by consent_given
      page = Consent.list_consent_records(%{consent_given: false}, %{page: 1, per_page: 10})
      assert length(page.entries) >= 1
      assert Enum.all?(page.entries, fn c -> c.consent_given == false end)

      # Test combined filters
      page = Consent.list_consent_records(
        %{user_id: user.id, consent_type: "analytics"}, 
        %{page: 1, per_page: 10}
      )
      assert length(page.entries) >= 1
      assert Enum.all?(page.entries, fn c -> 
        c.user_id == user.id && c.consent_type == "analytics" 
      end)
    end

    test "update_consent_record/3 updates a record", %{user: user, conn: conn} do
      # Create a consent record
      attrs = %{
        "consent_type" => "marketing",
        "consent_given" => true,
        "ip_address" => "127.0.0.1",
        "user_agent" => "Test Browser"
      }
      {:ok, %ConsentRecord{} = consent} = Consent.create_consent_record(attrs, user, conn)

      # Update the consent
      update_attrs = %{
        "consent_given" => false,
        "ip_address" => "192.168.1.1",
        "user_agent" => "New Browser"
      }
      assert {:ok, %ConsentRecord{} = updated_consent} = 
        Consent.update_consent_record(consent, update_attrs, user, conn)
      
      assert updated_consent.id == consent.id
      assert updated_consent.consent_given == false
      assert updated_consent.ip_address == "192.168.1.1"
      assert updated_consent.user_agent == "New Browser"
    end

    test "revoke_consent/2 revokes consent", %{user: user, conn: conn} do
      # Create a consent record
      attrs = %{
        "consent_type" => "marketing",
        "consent_given" => true,
        "ip_address" => "127.0.0.1",
        "user_agent" => "Test Browser"
      }
      {:ok, %ConsentRecord{} = consent} = Consent.create_consent_record(attrs, user, conn)

      # Revoke the consent
      assert {:ok, %ConsentRecord{} = revoked_consent} = Consent.revoke_consent(consent, user, conn)
      assert revoked_consent.id == consent.id
      assert revoked_consent.consent_given == false
      assert revoked_consent.revoked_at != nil
    end

    test "has_user_consent?/2 gets consent status", %{user: user, conn: conn} do
      # Create a consent record
      attrs = %{
        "consent_type" => "marketing",
        "consent_given" => true,
        "ip_address" => "127.0.0.1",
        "user_agent" => "Test Browser"
      }
      {:ok, _consent} = Consent.create_consent_record(attrs, user, conn)

      # Test getting consent status
      consent_status = Consent.has_user_consent?(user.id, "marketing")
      assert consent_status == true

      # Test non-existent consent type
      consent_status = Consent.has_user_consent?(user.id, "non_existent")
      assert consent_status == false
    end
  end

  describe "consent_types" do
    test "list_consent_types/0 returns all defined consent types" do
      types = Consent.list_consent_types()
      assert is_list(types)
      assert Enum.count(types) > 0
      assert Enum.all?(types, fn t -> is_map(t) end)
    end

    test "list_consent_type_ids/0 returns consent type IDs" do
      ids = Consent.list_consent_type_ids()
      assert is_list(ids)
      assert Enum.count(ids) > 0
      assert Enum.all?(ids, fn id -> is_binary(id) end)
      
      # Make sure IDs match those in the main list
      types = Consent.list_consent_types()
      type_ids = Enum.map(types, fn t -> t.id end)
      assert ids == type_ids
    end
  end
end