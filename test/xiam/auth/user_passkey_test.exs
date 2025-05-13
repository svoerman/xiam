defmodule XIAM.Auth.UserPasskeyTest do
  use XIAM.DataCase, async: false
  
  alias XIAM.Auth.UserPasskey
  alias XIAM.Users.User
  alias XIAM.Repo
  alias XIAM.ResilientTestHelper

  describe "user_passkey" do

    setup do
      # Use truly unique email with timestamp + random component
      unique_suffix = "#{System.system_time(:millisecond)}_#{:rand.uniform(100_000)}"
      unique_email = "test-passkey-#{unique_suffix}@example.com"
      
      # Use resilient DB operation pattern
      user_result = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        %User{}
        |> User.pow_changeset(%{
          email: unique_email,
          password: "Password1234!",
          password_confirmation: "Password1234!"
        })
        |> Repo.insert()
      end)
      
      # Ensure user creation succeeded and return the persisted user
      case user_result do
        {:ok, {:ok, user}} ->
          %{user: user}
        {:ok, user} when is_struct(user, User) -> # Handle cases where helper returns the struct directly
          %{user: user}
        failed_result ->
          raise "Setup failed: Could not create test user. Reason: #{inspect(failed_result)}"
      end
    end

    test "database insertion works with valid attributes", %{user: user} do
      # Test direct insertion with resilient DB operation
      {:ok, passkey} = ResilientTestHelper.safely_execute_db_operation(fn ->
        Repo.insert!(%UserPasskey{
          user_id: user.id,
          credential_id: <<1, 2, 3, 4>>,
          public_key: <<10, 11, 12, 13>>,
          sign_count: 0,
          friendly_name: "Test Device"
        })
      end)

      assert passkey.id != nil
      assert passkey.user_id == user.id
      assert passkey.credential_id == <<1, 2, 3, 4>>
      assert passkey.public_key == <<10, 11, 12, 13>>
    end

    test "changeset/2 with invalid attributes", %{user: user} do
      # Missing required fields
      attrs = %{user_id: user.id, friendly_name: "Test Device"}
      changeset = UserPasskey.changeset(%UserPasskey{}, attrs)
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :credential_id)
      assert Keyword.has_key?(changeset.errors, :public_key)
      assert Keyword.has_key?(changeset.errors, :sign_count)
    end

    test "create a passkey and retrieve by credential_id", %{user: user} do
      # Create a passkey
      {:ok, passkey} = ResilientTestHelper.safely_execute_db_operation(fn ->
        Repo.insert!(%UserPasskey{
          user_id: user.id,
          credential_id: <<1, 2, 3, 4>>,
          public_key: <<10, 11, 12, 13>>,
          sign_count: 0,
          friendly_name: "Test Device"
        })
      end)
      
      # Test retrieval by credential_id
      retrieved = UserPasskey.get_by_credential_id(<<1, 2, 3, 4>>)
      assert retrieved.id == passkey.id
      assert retrieved.credential_id == <<1, 2, 3, 4>>
    end

    test "list_by_user/1 returns passkeys for user", %{user: user} do
      # Create multiple passkeys for the same user
      Repo.insert!(%UserPasskey{
        user_id: user.id,
        credential_id: <<1, 2, 3, 4>>,
        public_key: <<10, 11, 12, 13>>,
        sign_count: 0,
        friendly_name: "Test Device 1"
      })
      
      Repo.insert!(%UserPasskey{
        user_id: user.id,
        credential_id: <<5, 6, 7, 8>>,
        public_key: <<10, 11, 12, 13>>,
        sign_count: 0,
        friendly_name: "Test Device 2"
      })
      
      # Create another user with a passkey
      {:ok, other_user} = %User{}
        |> User.pow_changeset(%{
          email: "other-user@example.com",
          password: "Password1234!",
          password_confirmation: "Password1234!"
        })
        |> Repo.insert()
      
      Repo.insert!(%UserPasskey{
        user_id: other_user.id,
        credential_id: <<9, 10, 11, 12>>,
        public_key: <<10, 11, 12, 13>>,
        sign_count: 0,
        friendly_name: "Other Device"
      })
      
      # Test list_by_user
      user_passkeys = UserPasskey.list_by_user(user.id)
      assert length(user_passkeys) == 2
      assert Enum.all?(user_passkeys, fn p -> p.user_id == user.id end)
    end

    test "find_by_credential_id_flexible/1 finds passkey with different formats", %{user: user} do
      # Create a passkey with a known credential ID
      credential_id = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10>>
      
      {:ok, passkey} = ResilientTestHelper.safely_execute_db_operation(fn ->
        Repo.insert!(%UserPasskey{
          user_id: user.id,
          credential_id: credential_id,
          public_key: <<10, 11, 12, 13>>,
          sign_count: 0,
          friendly_name: "Test Device"
        })
      end)
      
      # Test retrieval with different formats
      assert %UserPasskey{id: id} = UserPasskey.find_by_credential_id_flexible(credential_id)
      assert id == passkey.id
      
      # Test with base64 encoded value
      encoded = Base.encode64(credential_id, padding: false)
      assert %UserPasskey{id: id} = UserPasskey.find_by_credential_id_flexible(encoded)
      assert id == passkey.id
      
      # Test with url-safe base64 encoded value
      url_encoded = Base.url_encode64(credential_id, padding: false)
      assert %UserPasskey{id: id} = UserPasskey.find_by_credential_id_flexible(url_encoded)
      assert id == passkey.id
    end

    test "update_sign_count/2 updates sign count and last_used_at", %{user: user} do
      # Create a passkey
      {:ok, passkey} = ResilientTestHelper.safely_execute_db_operation(fn ->
        Repo.insert!(%UserPasskey{
          user_id: user.id,
          credential_id: <<1, 2, 3, 4>>,
          public_key: <<10, 11, 12, 13>>,
          sign_count: 0,
          friendly_name: "Test Device"
        })
      end)
      
      # Update sign count
      assert {:ok, updated} = UserPasskey.update_sign_count(passkey, 10)
      assert updated.sign_count == 10
      assert updated.last_used_at != nil
    end

    test "update_last_used/1 updates only the last_used_at timestamp", %{user: user} do
      # Create a passkey
      {:ok, passkey} = ResilientTestHelper.safely_execute_db_operation(fn ->
        Repo.insert!(%UserPasskey{
          user_id: user.id,
          credential_id: <<1, 2, 3, 4>>,
          public_key: <<10, 11, 12, 13>>,
          sign_count: 0,
          friendly_name: "Test Device"
        })
      end)
      
      # Update last_used_at
      assert {:ok, updated} = UserPasskey.update_last_used(passkey)
      assert updated.last_used_at != nil
      assert updated.sign_count == passkey.sign_count
    end

    test "delete/1 removes a passkey", %{user: user} do
      # Create a passkey
      {:ok, passkey} = ResilientTestHelper.safely_execute_db_operation(fn ->
        Repo.insert!(%UserPasskey{
          user_id: user.id,
          credential_id: <<1, 2, 3, 4>>,
          public_key: <<10, 11, 12, 13>>,
          sign_count: 0,
          friendly_name: "Test Device"
        })
      end)
      
      # Delete the passkey
      assert {:ok, _} = UserPasskey.delete(passkey)
      assert UserPasskey.get_by_credential_id(passkey.credential_id) == nil
    end
  end
end