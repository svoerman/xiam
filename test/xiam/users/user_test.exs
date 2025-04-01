defmodule XIAM.Users.UserTest do
  use XIAM.DataCase

  alias XIAM.Users.User
  alias Xiam.Rbac.{Role, Capability}
  alias XIAM.Repo

  describe "user schema" do
    test "pow_changeset/2 validates required fields" do
      changeset = User.pow_changeset(%User{}, %{})
      refute changeset.valid?
      assert errors_on(changeset).email
      assert errors_on(changeset).password
    end

    test "pow_changeset/2 validates email format" do
      changeset = User.pow_changeset(%User{}, %{
        email: "invalid-email",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      refute changeset.valid?
      assert "has invalid format" in errors_on(changeset).email
    end

    test "pow_changeset/2 validates password complexity" do
      changeset = User.pow_changeset(%User{}, %{
        email: "test@example.com",
        password: "simple",
        password_confirmation: "simple"
      })
      refute changeset.valid?
      assert errors_on(changeset).password
    end

    test "pow_changeset/2 creates a valid user" do
      changeset = User.pow_changeset(%User{}, %{
        email: "test@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      assert changeset.valid?
    end
  end

  describe "mfa functionality" do
    setup do
      {:ok, user} = %User{}
        |> User.pow_changeset(%{
          email: "mfa_test@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })
        |> Repo.insert()

      {:ok, user: user}
    end

    test "mfa_changeset/2 validates required fields", %{user: user} do
      changeset = User.mfa_changeset(user, %{mfa_enabled: true})
      refute changeset.valid?
      assert errors_on(changeset).mfa_secret
      assert errors_on(changeset).mfa_backup_codes

      # Disabling MFA should not require secret or backup codes
      changeset = User.mfa_changeset(user, %{mfa_enabled: false})
      assert changeset.valid?
    end

    test "generate_totp_secret/0 creates a valid TOTP secret" do
      secret = User.generate_totp_secret()
      assert is_binary(secret)
      assert byte_size(secret) > 0
    end

    test "generate_backup_codes/1 creates specified number of codes" do
      backup_codes = User.generate_backup_codes(5)
      assert length(backup_codes) == 5
      assert Enum.all?(backup_codes, fn code -> is_binary(code) end)
    end

    test "verify_totp/2 validates a TOTP code", %{user: user} do
      # We can't fully test TOTP verification without generating a valid code
      # But we can test the error case
      assert {:error, :no_mfa_secret} = User.verify_totp(user, "123456")
    end
  end

  describe "user capabilities" do
    setup do
      # Create a test user
      {:ok, user} = %User{}
        |> User.pow_changeset(%{
          email: "role_test@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })
        |> Repo.insert()

      # Create a role with capabilities
      {:ok, role} = %Role{
        name: "Test Role",
        description: "Role for testing capabilities"
      }
      |> Repo.insert()

      # Create a product for capabilities
      {:ok, product} = %Xiam.Rbac.Product{
        product_name: "Test Product",
        description: "Product for testing capabilities"
      }
      |> Repo.insert()
      
      # Create a capability
      {:ok, capability} = %Capability{
        name: "test_capability",
        description: "Capability for testing",
        product_id: product.id
      }
      |> Repo.insert()
      
      # Associate capability with role
      role
      |> Repo.preload(:capabilities)
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:capabilities, [capability])
      |> Repo.update!()

      # Reload role with capabilities
      role = Repo.preload(role, :capabilities)

      # Update user with role
      {:ok, user_with_role} = user
        |> User.role_changeset(%{role_id: role.id})
        |> Repo.update()

      {:ok, user: user_with_role, role: role, capability: capability}
    end

    test "has_capability?/2 returns true for user with capability", %{user: user, capability: capability} do
      user = Repo.preload(user, role: :capabilities)
      assert User.has_capability?(user, capability.name)
    end

    test "has_capability?/2 returns false for user without capability", %{user: user} do
      user = Repo.preload(user, role: :capabilities)
      assert User.has_capability?(user, "non_existent_capability") == false
    end

    test "has_capability?/2 returns false for user without role" do
      {:ok, user_without_role} = %User{}
        |> User.pow_changeset(%{
          email: "no_role@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })
        |> Repo.insert()
      
      user_without_role = Repo.preload(user_without_role, :role)
      assert User.has_capability?(user_without_role, "any_capability") == false
    end
  end
  
  describe "GDPR compliance" do
    setup do
      {:ok, user} = %User{}
        |> User.pow_changeset(%{
          email: "gdpr@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })
        |> Repo.insert()
        
      # Enable MFA for test
      secret = User.generate_totp_secret()
      backup_codes = User.generate_backup_codes()
      
      {:ok, user} = user
        |> User.mfa_changeset(%{
          mfa_enabled: true, 
          mfa_secret: secret, 
          mfa_backup_codes: backup_codes
        })
        |> Repo.update()
        
      {:ok, user: user}
    end
    
    test "anonymize_changeset/2 removes personal data", %{user: user} do
      anonymized_email = "anonymized-#{user.id}@deleted.example.com"
      
      changeset = User.anonymize_changeset(user, %{
        email: anonymized_email
      })
      
      assert changeset.valid?
      assert changeset.changes[:email] == anonymized_email
      assert changeset.changes[:mfa_enabled] == false
      assert changeset.changes[:mfa_secret] == nil
      assert changeset.changes[:mfa_backup_codes] == nil
    end
  end
end