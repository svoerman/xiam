defmodule XIAMWeb.AccountSettingsLiveTest do
  use ExUnit.Case, async: false
  import Mock

  alias XIAM.Users
  alias XIAM.Users.User
  alias XIAM.Auth.UserPasskey

  # Direct testing of handler functions without LiveView mounting
  describe "AccountSettingsLive event handlers" do
    setup do
      user = %User{
        id: "user-123",
        email: "test@example.com",
        name: "Test User"
      }
      
      passkey = %UserPasskey{
        id: "passkey-1",
        friendly_name: "Test Passkey",
        credential_id: "credential-1", 
        public_key: "test-key",
        sign_count: 1,
        user_id: "user-123"
      }
      
      {:ok, user: user, passkey: passkey}
    end

    test "toggle_theme changes theme state" do
      # Create a socket with initial light theme using explicit assigns
      socket = %Phoenix.LiveView.Socket{}
        |> struct(%{assigns: %{theme: "light", __changed__: %{}}, endpoint: XIAMWeb.Endpoint})
      
      # Test toggle theme handler
      {:noreply, updated_socket} = XIAMWeb.AccountSettingsLive.handle_event("toggle_theme", %{}, socket)
      
      # Should change to dark theme
      assert updated_socket.assigns.theme == "dark"
      
      # Toggle again
      {:noreply, final_socket} = XIAMWeb.AccountSettingsLive.handle_event("toggle_theme", %{}, updated_socket)
      
      # Should change back to light theme
      assert final_socket.assigns.theme == "light"  
    end

    test "modal events control visibility" do
      # Create a socket with modal initially hidden using proper LiveView socket structure
      socket = %Phoenix.LiveView.Socket{}
        |> struct(%{assigns: %{show_passkey_modal: false, __changed__: %{}}, endpoint: XIAMWeb.Endpoint})
      
      # Test show_passkey_modal handler
      {:noreply, updated_socket} = XIAMWeb.AccountSettingsLive.handle_event("show_passkey_modal", %{}, socket)
      
      # Should show the modal
      assert updated_socket.assigns.show_passkey_modal == true
      
      # Test close_modal handler
      {:noreply, final_socket} = XIAMWeb.AccountSettingsLive.handle_event("close_modal", %{}, updated_socket)
      
      # Should hide the modal
      assert final_socket.assigns.show_passkey_modal == false
    end

    test "save_passkey_name validates and handles passkey names", %{user: user} do
      # Create a socket with current user and proper LiveView structure
      socket = %Phoenix.LiveView.Socket{}
        |> struct(%{
          assigns: %{current_user: user, user: user, __changed__: %{}, flash: %{}},
          endpoint: XIAMWeb.Endpoint
        })
      
      # 1. Test with empty name
      params = %{"passkey" => %{"name" => ""}}
      
      {:noreply, error_socket} = XIAMWeb.AccountSettingsLive.handle_event(
        "save_passkey_name", 
        params, 
        socket
      )
      
      # Should set error message for empty name in flash
      assert Map.has_key?(error_socket.assigns.flash, "error")
      assert error_socket.assigns.flash["error"] =~ "cannot be empty"
      
      # 2. Test with valid name
      valid_params = %{"passkey" => %{"name" => "My New Passkey"}}
      
      # Mock the push_event function
      socket_with_push = %Phoenix.LiveView.Socket{}
        |> struct(%{
          assigns: %{current_user: user, user: user, __changed__: %{}, flash: %{}},
          endpoint: XIAMWeb.Endpoint,
          transport_pid: self()
        })
      
      # Call the handler with valid params
      {:noreply, success_socket} = XIAMWeb.AccountSettingsLive.handle_event(
        "save_passkey_name", 
        valid_params, 
        socket_with_push
      )
      
      # Should not have error message
      refute Map.has_key?(success_socket.assigns, :error_message)
    end

    test "delete_passkey handler removes passkey", %{user: user, passkey: passkey} do
      # Create a socket with initial passkeys list and proper LiveView structure
      socket = %Phoenix.LiveView.Socket{}
        |> struct(%{
          assigns: %{
            current_user: user,
            user: user,  # Add user key required by implementation
            passkeys: [passkey],
            __changed__: %{},
            flash: %{}
          },
          endpoint: XIAMWeb.Endpoint
        })
      
      # Mock both delete_user_passkey and list_user_passkeys functions
      with_mock Users, [
        delete_user_passkey: fn _user, _id -> {:ok, passkey} end,
        list_user_passkeys: fn _user -> [] end
      ] do
        # Call the handler with the passkey ID
        {:noreply, updated_socket} = XIAMWeb.AccountSettingsLive.handle_event(
          "delete_passkey", 
          %{"id" => passkey.id}, 
          socket
        )
        
        # Verify the mock was called with correct parameters
        assert_called Users.delete_user_passkey(user, passkey.id)
        
        # Verify passkey was removed from the list
        assert updated_socket.assigns[:passkeys] == []
        
        # Verify success message was set in flash
        assert Map.has_key?(updated_socket.assigns.flash, "info")
        assert updated_socket.assigns.flash["info"] =~ "deleted successfully"
      end
    end
    
    test "delete_passkey handles errors", %{user: user, passkey: passkey} do
      # Create a socket with initial passkeys list and proper LiveView structure
      socket = %Phoenix.LiveView.Socket{}
        |> struct(%{
          assigns: %{
            current_user: user,
            user: user,  # Add user key required by implementation
            passkeys: [passkey],
            __changed__: %{},
            flash: %{}
          },
          endpoint: XIAMWeb.Endpoint
        })
      
      # Mock both delete_user_passkey and list_user_passkeys functions
      with_mock Users, [
        delete_user_passkey: fn _user, _id -> {:error, "Database error"} end,
        list_user_passkeys: fn _user -> [passkey] end
      ] do
        # Call the handler with the passkey ID
        {:noreply, updated_socket} = XIAMWeb.AccountSettingsLive.handle_event(
          "delete_passkey", 
          %{"id" => passkey.id}, 
          socket
        )
        
        # Verify error message is set in flash
        assert Map.has_key?(updated_socket.assigns.flash, "error")
        assert updated_socket.assigns.flash["error"] =~ "Failed to delete passkey"
        
        # Verify passkeys list is unchanged
        assert updated_socket.assigns[:passkeys] == [passkey]
      end
    end

    test "passkey_registered handler success", %{user: user} do
      # Create a new passkey for testing
      new_passkey = %UserPasskey{
        id: "new-passkey-id",
        friendly_name: "New Passkey",
        credential_id: "test-credential",
        public_key: "test-public-key",
        sign_count: 0,
        user_id: user.id
      }
      
      # Create a socket with initial state and proper LiveView structure
      socket = %Phoenix.LiveView.Socket{}
        |> struct(%{
          assigns: %{
            current_user: user,
            user: user,  # Add user key required by implementation
            passkeys: [],
            show_passkey_modal: true,
            __changed__: %{},
            flash: %{}
          },
          endpoint: XIAMWeb.Endpoint
        })
      
      # Mock the Users module to return our passkey for the list call
      with_mock Users, [list_user_passkeys: fn _user -> [new_passkey] end] do
        # Call the handler directly - the actual implementation doesn't use any params
        {:noreply, updated_socket} = XIAMWeb.AccountSettingsLive.handle_event("passkey_registered", %{}, socket)
        
        # Verify the mock was called with correct user
        assert_called Users.list_user_passkeys(user)
        
        # Verify passkeys were updated in the socket
        assert updated_socket.assigns[:passkeys] == [new_passkey]
        
        # Verify modal was closed
        assert updated_socket.assigns[:show_passkey_modal] == false
        
        # Verify flash message was set
        assert Map.has_key?(updated_socket.assigns.flash, "info")
        assert updated_socket.assigns.flash["info"] == "Passkey registered successfully"
      end
    end
    
    test "passkey_error handler displays error message", %{user: user} do
      # Create a socket with initial state and proper LiveView structure
      socket = %Phoenix.LiveView.Socket{}
        |> struct(%{
          assigns: %{
            current_user: user,
            user: user,  # Add user key required by implementation
            passkeys: [],
            show_passkey_modal: true,
            __changed__: %{},
            flash: %{}
          },
          endpoint: XIAMWeb.Endpoint
        })
      
      # Test params for the event with error message
      params = %{"message" => "Invalid attestation"}
      
      # Call the handler directly
      {:noreply, updated_socket} = XIAMWeb.AccountSettingsLive.handle_event("passkey_error", params, socket)
      
      # Verify error message was set in flash
      assert Map.has_key?(updated_socket.assigns.flash, "error")
      assert updated_socket.assigns.flash["error"] =~ "Passkey error: Invalid attestation"
    end
    
    test "passkeys_loaded handler", %{user: user} do
      # Create a socket with initial state and proper LiveView structure
      socket = %Phoenix.LiveView.Socket{}
        |> struct(%{
          assigns: %{
            current_user: user,
            user: user,  # Add user key required by implementation
            __changed__: %{},
            flash: %{}
          },
          endpoint: XIAMWeb.Endpoint
        })
      
      # Test with passkeys param matching the implementation
      sample_passkeys = [
        %{"id" => "passkey-1", "friendly_name" => "Test Passkey", "created_at" => nil, "last_used_at" => nil, "credential_id" => "cred-1"}
      ]
      
      params = %{"passkeys" => sample_passkeys}
      
      # Call the handler directly
      {:noreply, updated_socket} = XIAMWeb.AccountSettingsLive.handle_event("passkeys_loaded", params, socket)
      
      # Verify the passkeys were atomized and assigned
      assert is_list(updated_socket.assigns[:passkeys])
      assert length(updated_socket.assigns[:passkeys]) == 1
    end

    # Note: We're not testing on_mount functions here as they are part of the Phoenix LiveView lifecycle
    # and are configured via use XIAMWeb, :live_view in the AccountSettingsLive module.
  end
end
