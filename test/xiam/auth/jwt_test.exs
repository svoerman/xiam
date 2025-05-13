defmodule XIAM.Auth.JWTTest do
  use XIAM.DataCase, async: false

  alias XIAM.Auth.JWT
  alias XIAM.Users.User
  alias XIAM.Repo

  describe "JWT authentication" do
    setup do
      # Create a test user
      {:ok, user} = %User{}
        |> User.pow_changeset(%{
          email: "test@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })
        |> Repo.insert()

      {:ok, user: user}
    end

    test "generate_token/1 returns valid token for user", %{user: user} do
      assert {:ok, token, _claims} = JWT.generate_token(user)
      assert is_binary(token)
      assert String.length(token) > 0
    end

    test "verify_token/1 validates a legitimate token", %{user: user} do
      {:ok, token, _claims} = JWT.generate_token(user)
      assert {:ok, claims} = JWT.verify_token(token)
      # The ID could be either an integer or string depending on JOSE implementation
      assert to_string(claims["sub"]) == to_string(user.id)
    end

    test "verify_token/1 rejects a tampered token", %{user: user} do
      {:ok, token, _claims} = JWT.generate_token(user)
      # Tamper with the token by appending a character
      tampered_token = token <> "a"
      assert {:error, _reason} = JWT.verify_token(tampered_token)
    end

    test "get_user_from_claims/1 retrieves the correct user", %{user: user} do
      {:ok, token, _claims} = JWT.generate_token(user)
      {:ok, claims} = JWT.verify_token(token)
      assert {:ok, retrieved_user} = JWT.get_user_from_claims(claims)
      assert retrieved_user.id == user.id
      assert retrieved_user.email == user.email
    end

    test "get_user_from_claims/1 handles invalid user ID" do
      claims = %{"sub" => "9999999"}
      assert {:error, :user_not_found} = JWT.get_user_from_claims(claims)
    end
  end
end