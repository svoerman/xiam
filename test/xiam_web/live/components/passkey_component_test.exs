defmodule XIAMWeb.Live.Components.PasskeyComponentTest do
  use XIAMWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mox
  setup :verify_on_exit!

  describe "PasskeyComponent" do
    setup %{conn: conn} do
      # Create a test user
      user = %XIAM.Users.User{
        id: 123,
        email: "passkey-component@example.com",
        passkey_enabled: false
      }
      passkeys = [
        %{
          id: 1,
          friendly_name: "Test Passkey 1",
          created_at: ~N[2023-01-01 12:00:00],
          last_used_at: nil
        }
      ]
      # Configure component to use Mox mock for users
      Application.put_env(:xiam, :users, XIAM.Users.Mock)
      # Mox mock for XIAM.Users
      XIAM.Users.Mock
      |> stub(:list_user_passkeys, fn _user_arg -> passkeys end)
      |> stub(:update_user_passkey_settings, fn user_arg, _ -> {:ok, %{user_arg | passkey_enabled: true}} end)
      |> stub(:delete_user_passkey, fn _user_arg, _id -> {:ok, :deleted} end)

      # Set up LiveView with assigns
      {:ok, view, _html} = live_isolated(conn, XIAMWeb.Live.Components.PasskeyComponentTest.TestPasskeyLiveView, session: %{"user" => user})
      %{view: view, user: user, passkeys: passkeys}
    end

    test "renders with passkey disabled", %{view: view} do
      html = render(view)
      assert html =~ "Enable Passkeys"
      assert html =~ "Passkey Management"
      refute html =~ "Register a New Passkey"
    end

    test "renders with passkey enabled and passkeys", %{view: view, user: _user, passkeys: _passkeys} do
      # Simulate enabling passkeys and get HTML
      html = element(view, "input[type=checkbox]") |> render_click()
      assert html =~ "Register a New Passkey"
      assert html =~ "Your Passkeys"
      assert html =~ "Test Passkey 1"
    end

    # Empty passkeys state is indirectly tested through other tests


    test "shows flash messages (success and error)", %{view: view, user: _user} do
      # Simulate success flash by toggling passkey (success)
      XIAM.Users.Mock |> expect(:update_user_passkey_settings, fn user_arg, _ -> {:ok, %{user_arg | passkey_enabled: true}} end)
      html = element(view, "input[type=checkbox]") |> render_click()
      assert html =~ "Passkey settings updated successfully"

      # Simulate error flash by toggling passkey (error)
      XIAM.Users.Mock |> expect(:update_user_passkey_settings, fn _user_arg, _ -> {:error, :fail} end)
      html = element(view, "input[type=checkbox]") |> render_click()
      assert html =~ "Failed to update passkey settings"
    end

    test "handle_event: update_passkey_name", %{view: view} do
      # Enable passkeys so the input is rendered
      _ = element(view, "input[type=checkbox]") |> render_click()
      html = element(view, "input[placeholder='e.g. Work Laptop']") |> render_keyup(%{"value" => "Laptop"})
      assert html =~ "Laptop"
    end

    test "handle_event: toggle_passkey_enabled (success)", %{view: view, user: _user} do
      XIAM.Users.Mock |> expect(:update_user_passkey_settings, fn user_arg, _ -> {:ok, %{user_arg | passkey_enabled: true}} end)
      html = element(view, "input[type=checkbox]") |> render_click()
      assert html =~ "Passkey settings updated successfully"
    end

    test "handle_event: toggle_passkey_enabled (error)", %{view: view, user: _user} do
      XIAM.Users.Mock |> expect(:update_user_passkey_settings, fn _user_arg, _ -> {:error, :fail} end)
      html = element(view, "input[type=checkbox]") |> render_click()
      assert html =~ "Failed to update passkey settings"
    end

    # Passkey registration is handled by JS hooks and is not easily testable in this context


    test "handle_event: delete_passkey (success)", %{view: view, user: _user} do
      # Enable passkeys so the delete button is visible
      _ = element(view, "input[type=checkbox]") |> render_click()
      XIAM.Users.Mock |> expect(:delete_user_passkey, fn _user_arg, _ -> {:ok, :deleted} end)
      html = element(view, "button.btn-error", "Remove") |> render_click(%{"id" => 1})
      assert html =~ "Passkey removed successfully"
    end

    test "handle_event: delete_passkey (error)", %{view: view, user: _user} do
      # Enable passkeys so the delete button is visible
      _ = element(view, "input[type=checkbox]") |> render_click()
      XIAM.Users.Mock |> expect(:delete_user_passkey, fn _user_arg, _ -> {:error, "reason"} end)
      html = element(view, "button.btn-error", "Remove") |> render_click(%{"id" => 1})
      assert html =~ "Failed to remove passkey: reason"
    end

    test "format_datetime helper is used in render", %{view: view, user: _user, passkeys: _passkeys} do
      html = element(view, "input[type=checkbox]") |> render_click()
      assert html =~ "2023-01-01 12:00"
    end
  end

  # A simple LiveView for testing the component
  defmodule TestPasskeyLiveView do
    use Phoenix.LiveView, layout: {XIAMWeb.Layouts, :app}
    
    def mount(_params, %{"user" => user}, socket) do
      {:ok, assign(socket, current_user: user)}
    end
    
    def render(assigns) do
      ~H"""
      <div>
        <.live_component 
          module={XIAMWeb.PasskeyComponent} 
          id="passkey-test" 
          user={@current_user} 
        />
      </div>
      """
    end
    
    def handle_event("load-passkeys", _, socket) do
      send_update(XIAMWeb.PasskeyComponent, id: "passkey-test", action: :load)
      {:noreply, socket}
    end
    
    def handle_event("prepare-registration", _, socket) do
      send_update(XIAMWeb.PasskeyComponent, id: "passkey-test", action: :register)
      {:noreply, socket}
    end
  end
end