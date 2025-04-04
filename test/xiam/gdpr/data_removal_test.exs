defmodule XIAM.GDPR.DataRemovalTest do
  use XIAM.DataCase

  import Mock

  alias XIAM.GDPR.DataRemoval
  alias XIAM.Users.User
  alias XIAM.GDPR.Consent
  alias XIAM.Repo

  describe "data removal" do
    setup do
      # Create a test user
      {:ok, user} = %User{}
        |> User.pow_changeset(%{
          email: "data_removal_test@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })
        |> Repo.insert()

      # Create consent records
      {:ok, _consent} = Consent.record_consent(%{
        consent_type: "marketing",
        consent_given: true,
        user_id: user.id
      })

      {:ok, user: user}
    end

    test "anonymize_user/1 anonymizes a user's data", %{user: user} do
      original_email = user.email

      # Mock the audit logger to avoid actual logging
      with_mock XIAM.Jobs.AuditLogger, [log_action: fn _, _, _, _ -> {:ok, true} end] do
        # Test the actual module function
        assert {:ok, anonymized_user} = DataRemoval.anonymize_user(user.id)

        # Email should be changed
        assert anonymized_user.email != original_email
        assert String.contains?(anonymized_user.email, "anonymized_#{user.id}")

        # MFA fields should be reset
        assert anonymized_user.mfa_enabled == false
        assert anonymized_user.mfa_secret == nil
        assert anonymized_user.mfa_backup_codes == nil

        # User should still exist in the database
        assert Repo.get(User, user.id) != nil

        # Verify audit log was called
        assert_called XIAM.Jobs.AuditLogger.log_action("user_anonymized", user.id, %{}, "N/A")
      end
    end

    test "anonymize_user/1 handles transaction errors", %{user: user} do
      # Force a validation error by creating an invalid email
      with_mock User, [:passthrough], [anonymize_changeset: fn _, _ ->
        Ecto.Changeset.change(%User{}, %{email: nil})
        |> Ecto.Changeset.validate_required([:email])
      end] do
        assert {:error, %Ecto.Changeset{}} = DataRemoval.anonymize_user(user.id)
      end
    end

    test "anonymize_user/1 returns error for non-existent user" do
      assert {:error, :user_not_found} = DataRemoval.anonymize_user(999999)
    end

    test "delete_user/1 completely removes a user", %{user: user} do
      # Mock the audit logger to avoid actual logging
      with_mock XIAM.Jobs.AuditLogger, [log_action: fn _, _, _, _ -> {:ok, true} end] do
        # Test the actual module function
        assert {:ok, deleted_user_id} = DataRemoval.delete_user(user.id)
        assert deleted_user_id == user.id

        # User should no longer exist in the database
        assert Repo.get(User, user.id) == nil

        # Consent records should be deleted via database cascade
        assert Repo.all(Consent) |> Enum.filter(fn c -> c.user_id == user.id end) == []

        # Verify audit log was called
        assert_called XIAM.Jobs.AuditLogger.log_action("user_deleted", user.id, %{}, "N/A")
      end
    end

    test "delete_user/1 handles transaction errors", %{user: user} do
      # Mock the transaction to simulate a failure during deletion
      with_mock Repo, [:passthrough], [transaction: fn _func ->
        {:error, :user, %Ecto.Changeset{}, %{}}
      end] do
        assert {:error, %Ecto.Changeset{}} = DataRemoval.delete_user(user.id)
      end
    end

    test "delete_user/1 returns error for non-existent user" do
      assert {:error, :user_not_found} = DataRemoval.delete_user(999999)
    end
  end
end
