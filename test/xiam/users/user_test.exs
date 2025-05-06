defmodule XIAM.Users.UserTest do
  use XIAM.DataCase, async: false

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
      # Generate a timestamp for unique test data
      timestamp = System.system_time(:second)
      
      # Clean up existing test data
      import Ecto.Query
      Repo.delete_all(from u in User, where: like(u.email, "%mfa_test%"))
      
      email = "mfa_test_#{timestamp}@example.com"
      {:ok, user} = %User{}
        |> User.pow_changeset(%{
          email: email,
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
      # Set up database connection in shared mode for all tests in this group
      # This helps prevent ownership issues when async processes are involved
      # Use pattern matching with fallback to handle if connection is already checked out
      case Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo) do
        :ok -> :ok
        {:already, :owner} -> :ok
      end
      
      Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
      
      # Generate a timestamp for unique test data
      timestamp = System.system_time(:second)
      
      # Clean up existing test data in the correct order to respect foreign keys
      import Ecto.Query
      
      # First delete entity access records that depend on users and roles
      Repo.delete_all(from ea in Xiam.Rbac.EntityAccess,
                      join: u in User, on: ea.user_id == u.id,
                      where: like(u.email, "%role_test%"))
                      
      # Then delete other records
      Repo.delete_all(from u in User, where: like(u.email, "%role_test%"))
      Repo.delete_all(from r in Role, where: like(r.name, "%Test_Role_%"))
      Repo.delete_all(from p in Xiam.Rbac.Product, where: like(p.product_name, "%Test_Capability_Product_%"))
      
      # Create a test user with unique email
      email = "role_test_#{timestamp}@example.com"
      {:ok, user} = %User{}
        |> User.pow_changeset(%{
          email: email,
          password: "Password123!",
          password_confirmation: "Password123!"
        })
        |> Repo.insert()

      # Create a role with capabilities and unique name
      role_name = "Test_Role_#{timestamp}"
      {:ok, role} = %Role{
        name: role_name,
        description: "Role for testing capabilities"
      }
      |> Repo.insert()

      # Create a product for capabilities with unique name
      product_name = "Test_Capability_Product_#{timestamp}"
      {:ok, product} = %Xiam.Rbac.Product{
        product_name: product_name,
        description: "Product for testing capabilities"
      }
      |> Repo.insert()
      
      # Create a capability with unique name
      capability_name = "test_capability_#{timestamp}"
      {:ok, capability} = %Capability{
        name: capability_name,
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
        
      # Register a teardown function that cleans up entity access data
      # We use checkout inside the function so the connection isn't lost between setup and teardown
      # This prevents ownership errors when the function exits
      on_exit(fn ->
        # Use our resilient pattern for database operations
        XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
          # Get our own connection for cleanup - don't rely on the test connection which might be gone
          case Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo) do
            :ok -> :ok
            {:already, :owner} -> :ok
          end
          
          # Set shared mode to ensure subprocesses can access the connection
          Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
          
          import Ecto.Query
          # First delete entity access records that depend on users
          Repo.delete_all(from ea in Xiam.Rbac.EntityAccess,
                          join: u in User, on: ea.user_id == u.id,
                          where: like(u.email, "%role_test%"))
        end)
      end)

      {:ok, user: user_with_role, role: role, capability: capability}
    end

    test "has_capability?/2 returns true for user with capability", %{user: user, role: role, capability: capability} do
      XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        case Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo) do
          :ok -> :ok
          {:already, :owner} -> :ok
        end
        
        # Set shared mode to ensure subprocesses can access the connection
        Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})

        # Setup user-role association 
        # Use set_user_access with appropriate params to assign the role to the user
        {:ok, _} = Xiam.Rbac.AccessControl.set_user_access(%{
          user_id: user.id,
          role_id: role.id,
          entity_type: "system",
          entity_id: 0
        })

        # Associate the capability with the role directly using Repo.query
        # Since we don't have a dedicated RoleCapability schema, we'll use a raw SQL query
        {:ok, _} = Repo.query(
          "INSERT INTO roles_capabilities (role_id, capability_id) VALUES ($1, $2)",
          [role.id, capability.id]
        )

        # Check if user has capability
        assert User.has_capability?(user, capability.name) == true
      end)
    end

    test "has_capability?/2 returns false for user without capability", %{user: user, role: role, capability: capability} do
      # Use resilient test helper to handle potential DB connection issues
      XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        # Ensure we have ownership of the DB connection for this test
        case Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo) do
          :ok -> :ok
          {:already, :owner} -> :ok
        end
        
        # Set shared mode to ensure subprocesses can access the connection
        Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
        
        # Setup user-role association 
        # Use set_user_access with appropriate params to assign the role to the user
        {:ok, _} = Xiam.Rbac.AccessControl.set_user_access(%{
          user_id: user.id,
          role_id: role.id,
          entity_type: "system",
          entity_id: 0
        })
        
        # Purposely do NOT assign the capability to the role
        
        # Check if user has capability
        assert User.has_capability?(user, capability.name) == false
      end)
    end

    test "has_capability?/2 returns false for user without role", %{capability: _capability} do
      # Use resilient test helper to handle potential DB connection issues
      XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        # Ensure we have ownership of the DB connection for this test
        case Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo) do
          :ok -> :ok
          {:already, :owner} -> :ok
        end
        
        # Set shared mode to ensure subprocesses can access the connection
        Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
        
        timestamp = System.system_time(:second)
        email = "no_role_#{timestamp}@example.com"
        
        {:ok, user_without_role} = %User{}
          |> User.pow_changeset(%{
            email: email,
            password: "Password123!",
            password_confirmation: "Password123!"
          })
          |> Repo.insert()
          
        user_without_role = Repo.preload(user_without_role, role: :capabilities)
        assert User.has_capability?(user_without_role, "any_capability") == false
      end)
    end
  end
  
  describe "GDPR compliance" do
    setup do
      # Generate a timestamp for unique test data
      timestamp = System.system_time(:second)
      
      # Clean up existing test data
      import Ecto.Query
      Repo.delete_all(from u in User, where: like(u.email, "%gdpr%"))
      
      email = "gdpr_#{timestamp}@example.com"
      {:ok, user} = %User{}
        |> User.pow_changeset(%{
          email: email,
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