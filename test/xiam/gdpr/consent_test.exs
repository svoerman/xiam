defmodule XIAM.GDPR.ConsentTest do
  use XIAM.DataCase

  alias XIAM.GDPR.Consent
  alias XIAM.Users.User
  alias XIAM.Repo

  describe "gdpr consent" do
    setup do
      # Create a test user
      {:ok, user} = %User{}
        |> User.pow_changeset(%{
          email: "gdpr_test@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })
        |> Repo.insert()
      
      {:ok, user: user}
    end

    test "changeset with valid attributes", %{user: user} do
      valid_attrs = %{
        consent_type: "marketing",
        consent_given: true,
        ip_address: "127.0.0.1",
        user_agent: "Test Browser",
        user_id: user.id
      }

      changeset = Consent.changeset(%Consent{}, valid_attrs)
      assert changeset.valid?
    end

    test "changeset with invalid attributes" do
      invalid_attrs = %{
        consent_given: true,
        ip_address: "127.0.0.1"
        # Missing required fields: consent_type, user_id
      }

      changeset = Consent.changeset(%Consent{}, invalid_attrs)
      assert !changeset.valid?
      assert "can't be blank" in errors_on(changeset).consent_type
      assert "can't be blank" in errors_on(changeset).user_id
    end

    test "record_consent/1 creates a new consent record", %{user: user} do
      valid_attrs = %{
        consent_type: "marketing",
        consent_given: true,
        ip_address: "127.0.0.1",
        user_agent: "Test Browser",
        user_id: user.id
      }

      assert {:ok, consent} = Consent.record_consent(valid_attrs)
      assert consent.consent_type == "marketing"
      assert consent.consent_given == true
      assert consent.user_id == user.id
    end

    test "revoke_consent/2 revokes an existing consent", %{user: user} do
      # First create a consent record
      {:ok, consent} = Consent.record_consent(%{
        consent_type: "marketing",
        consent_given: true,
        user_id: user.id
      })

      # Now revoke it
      revocation_attrs = %{
        consent_given: false,
        ip_address: "127.0.0.1",
        user_agent: "Test Browser"
      }

      assert {:ok, revoked} = Consent.revoke_consent(consent.id, revocation_attrs)
      assert revoked.consent_given == false
      assert revoked.revoked_at != nil
    end

    test "get_user_consents/1 returns all user consents", %{user: user} do
      # Create multiple consent records for the user
      Consent.record_consent(%{
        consent_type: "marketing",
        consent_given: true,
        user_id: user.id
      })

      Consent.record_consent(%{
        consent_type: "analytics",
        consent_given: false,
        user_id: user.id
      })

      consents = Consent.get_user_consents(user.id)
      assert length(consents) == 2
      assert Enum.all?(consents, fn c -> c.user_id == user.id end)
    end

    test "has_valid_consent?/2 checks for valid consent", %{user: user} do
      # Create a valid consent
      Consent.record_consent(%{
        consent_type: "marketing",
        consent_given: true,
        user_id: user.id
      })

      # Create an invalid consent (consent_given = false)
      Consent.record_consent(%{
        consent_type: "analytics",
        consent_given: false,
        user_id: user.id
      })

      # Test valid consent
      assert Consent.has_valid_consent?(user.id, "marketing") == true
      
      # Test invalid consent
      assert Consent.has_valid_consent?(user.id, "analytics") == false
      
      # Test non-existent consent
      assert Consent.has_valid_consent?(user.id, "nonexistent") == false
    end
  end
end