defmodule XIAMWeb.API.PasskeyControllerTest do
  use XIAMWeb.ConnCase, async: false
  
  alias XIAM.Auth.UserPasskey
  alias XIAM.Users.User
  alias XIAM.Repo

  import Plug.Conn

  describe "with session authentication" do
    setup %{conn: conn} do
      # Create a test user
      {:ok, user} = %User{}
        |> User.pow_changeset(%{
          email: "passkeytest@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })
        |> Repo.insert()

      # Initialize test session and simulate Pow session authentication
      conn = Plug.Test.init_test_session(conn, %{})
      conn = Pow.Plug.assign_current_user(conn, user, otp_app: :xiam)
      conn = fetch_session(conn)
      conn = put_req_header(conn, "accept", "application/json")

      {:ok, conn: conn, user: user}
    end

    test "registration_options returns correct RP name and structure", %{conn: conn} do
      conn = get(conn, "/api/passkeys/registration_options")
      assert json_response(conn, 200)["success"] == true
      opts = json_response(conn, 200)["options"]

      assert is_map(opts)
      assert is_binary(opts["challenge"])
      assert is_map(opts["rp"])
      assert opts["rp"]["name"] == "XIAM"
      assert opts["rp"]["id"] == "localhost"
      assert is_map(opts["user"])
      assert is_list(opts["pubKeyCredParams"])
      assert is_integer(opts["timeout"])
      assert is_binary(opts["attestation"])
      assert is_map(opts["authenticatorSelection"])
    end
    
    test "register fails without an active challenge", %{conn: conn} do
      # Clear any existing challenge
      conn = delete_session(conn, :passkey_challenge)
      
      response = conn
        |> post("/api/passkeys/register", %{"attestation" => %{}, "friendly_name" => "Test"})
        |> json_response(400)
      
      assert response["error"] == "No active registration session found"
    end
    
    test "list_passkeys returns passkeys for the authenticated user", %{conn: conn, user: user} do
      # Create some passkeys for the user
      {:ok, _passkey1} = Repo.insert(%UserPasskey{
        user_id: user.id,
        credential_id: <<1, 2, 3, 4>>,
        public_key: <<10, 11, 12, 13>>,
        sign_count: 0,
        friendly_name: "Passkey 1"
      })
      
      {:ok, _passkey2} = Repo.insert(%UserPasskey{
        user_id: user.id,
        credential_id: <<5, 6, 7, 8>>,
        public_key: <<10, 11, 12, 13>>,
        sign_count: 0,
        friendly_name: "Passkey 2"
      })
      
      response = conn
        |> get("/api/passkeys")
        |> json_response(200)
      
      assert response["success"] == true
      assert length(response["passkeys"]) == 2
      assert Enum.any?(response["passkeys"], fn p -> p["friendly_name"] == "Passkey 1" end)
      assert Enum.any?(response["passkeys"], fn p -> p["friendly_name"] == "Passkey 2" end)
    end
    
    test "delete_passkey deletes a passkey belonging to the user", %{conn: conn, user: user} do
      # Create a passkey for the user
      {:ok, passkey} = Repo.insert(%UserPasskey{
        user_id: user.id,
        credential_id: <<1, 2, 3, 4>>,
        public_key: <<10, 11, 12, 13>>,
        sign_count: 0,
        friendly_name: "Passkey to Delete"
      })
      
      response = conn
        |> delete("/api/passkeys/#{passkey.id}")
        |> json_response(200)
      
      assert response["success"] == true
      refute Repo.get(UserPasskey, passkey.id)
    end
  end

  describe "API authentication" do
    setup %{conn: conn} do
      # Create a test user for token handoff tests
      {:ok, user} = %User{}
        |> User.pow_changeset(%{
          email: "api-passkeytest@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })
        |> Repo.insert()

      conn = Plug.Test.init_test_session(conn, %{})
      conn = Pow.Plug.assign_current_user(conn, user, otp_app: :xiam)
      conn = fetch_session(conn)
      {:ok, conn: conn, user: user}
    end

    test "token handoff: valid token allows session creation", %{conn: conn, user: user} do
      user_id = user.id
      timestamp = :os.system_time(:second)
      secret = Application.get_env(:xiam, XIAMWeb.Endpoint)[:secret_key_base]
      hmac = :crypto.mac(:hmac, :sha256, secret, "#{user_id}:#{timestamp}") |> Base.url_encode64(padding: false)
      auth_token = "#{user_id}:#{timestamp}:#{hmac}"
      conn = get(conn, "/auth/passkey/complete?auth_token=#{URI.encode_www_form(auth_token)}")
      assert conn.status == 302
      assert get_resp_header(conn, "location") == ["/admin"]
    end

    test "token handoff: tampered token is rejected", %{conn: conn, user: user} do
      user_id = user.id
      timestamp = :os.system_time(:second)
      secret = Application.get_env(:xiam, XIAMWeb.Endpoint)[:secret_key_base]
      hmac = :crypto.mac(:hmac, :sha256, secret, "#{user_id}:#{timestamp}") |> Base.url_encode64(padding: false)
      tampered_token = "#{user_id + 1}:#{timestamp}:#{hmac}"
      conn = get(conn, "/auth/passkey/complete?auth_token=#{URI.encode_www_form(tampered_token)}")
      assert conn.status == 302
      assert get_resp_header(conn, "location") == ["/session/new"]
    end

    test "token handoff: expired token is rejected", %{conn: conn, user: user} do
      user_id = user.id
      timestamp = :os.system_time(:second) - 86_400
      secret = Application.get_env(:xiam, XIAMWeb.Endpoint)[:secret_key_base]
      hmac = :crypto.mac(:hmac, :sha256, secret, "#{user_id}:#{timestamp}") |> Base.url_encode64(padding: false)
      expired_token = "#{user_id}:#{timestamp}:#{hmac}"
      conn = get(conn, "/auth/passkey/complete?auth_token=#{URI.encode_www_form(expired_token)}")
      assert conn.status == 302
      assert get_resp_header(conn, "location") == ["/session/new"]
    end

    test "token handoff: replayed token is rejected", %{conn: conn, user: user} do
      user_id = user.id
      timestamp = :os.system_time(:second)
      secret = Application.get_env(:xiam, XIAMWeb.Endpoint)[:secret_key_base]
      hmac = :crypto.mac(:hmac, :sha256, secret, "#{user_id}:#{timestamp}") |> Base.url_encode64(padding: false)
      auth_token = "#{user_id}:#{timestamp}:#{hmac}"
      conn1 = get(conn, "/auth/passkey/complete?auth_token=#{URI.encode_www_form(auth_token)}")
      assert conn1.status == 302
      assert get_resp_header(conn1, "location") == ["/admin"]
      conn2 = get(conn, "/auth/passkey/complete?auth_token=#{URI.encode_www_form(auth_token)}")
      assert conn2.status == 302
      assert get_resp_header(conn2, "location") == ["/session/new"]
    end

    test "token handoff: missing token is rejected", %{conn: conn} do
      conn = get(conn, "/auth/passkey/complete")
      assert conn.status == 302
      assert get_resp_header(conn, "location") == ["/session/new"]
    end

    test "token handoff: malformed token is rejected", %{conn: conn} do
      conn = get(conn, "/auth/passkey/complete?auth_token=notavalidtoken")
      assert conn.status == 302
      assert get_resp_header(conn, "location") == ["/session/new"]
    end
  end
end
