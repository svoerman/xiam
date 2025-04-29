defmodule XIAM.Auth.PasskeyRepositoryTest do
  use XIAM.DataCase

  alias XIAM.Auth.PasskeyRepository
  alias XIAM.Auth.UserPasskey
  alias XIAM.Users.User

  @valid_user_attrs %{
    email: "test@example.com",
    name: "Test User",
    password: "password",
    password_confirmation: "password"
  }
  
  @valid_passkey_attrs %{
    credential_id: "dGVzdF9jcmVkZW50aWFsX2lk",
    public_key: <<1, 2, 3, 4>>,
    sign_count: 0,
    friendly_name: "Test passkey",
    aaguid: <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>
  }

  describe "user operations" do
    test "get_user_by_email/1 returns user when found" do
      {:ok, user} = create_user()
      assert {:ok, %User{id: id}} = PasskeyRepository.get_user_by_email(user.email)
      assert id == user.id
    end

    test "get_user_by_email/1 returns error when user not found" do
      assert {:error, :user_not_found} = PasskeyRepository.get_user_by_email("nonexistent@example.com")
    end
  end

  describe "passkey operations" do
    setup do
      {:ok, user} = create_user()
      {:ok, passkey} = create_passkey(user)
      %{user: user, passkey: passkey}
    end

    test "get_user_passkeys/1 returns all passkeys for user", %{user: user, passkey: passkey} do
      passkeys = PasskeyRepository.get_user_passkeys(user)
      assert length(passkeys) == 1
      assert List.first(passkeys).id == passkey.id
    end
    
    test "get_passkey_with_user/1 returns passkey and user when found", %{passkey: passkey} do
      assert {:ok, found_passkey, user} = 
        PasskeyRepository.get_passkey_with_user(passkey.credential_id)
      assert found_passkey.id == passkey.id
      assert user.id == passkey.user_id
    end
    
    test "get_passkey_with_user/1 returns error when passkey not found" do
      assert {:error, :credential_not_found} = 
        PasskeyRepository.get_passkey_with_user("nonexistent_credential_id", suppress_log: true)
    end
    
    test "update_sign_count/2 updates sign count", %{passkey: passkey} do
      new_count = passkey.sign_count + 1
      assert {:ok, updated_passkey} = PasskeyRepository.update_sign_count(passkey, new_count)
      assert updated_passkey.sign_count == new_count
    end
  end
  
  # Helper functions
  
  defp create_user do
    %User{}
    |> User.changeset(@valid_user_attrs)
    |> Repo.insert()
  end
  
  defp create_passkey(user) do
    %UserPasskey{}
    |> UserPasskey.changeset(Map.put(@valid_passkey_attrs, :user_id, user.id))
    |> Repo.insert()
  end
end
