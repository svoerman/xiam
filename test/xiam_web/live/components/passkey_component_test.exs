defmodule XIAMWeb.Live.Components.PasskeyComponentTest do
  use XIAMWeb.ConnCase, async: true
  
  import Phoenix.LiveViewTest
  alias XIAM.Auth.UserPasskey
  alias XIAM.Users.User
  alias XIAM.Repo

  describe "PasskeyComponent" do
    setup %{conn: conn} do
      # Create a test user
      {:ok, user} = %User{}
        |> User.pow_changeset(%{
          email: "passkey-component@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })
        |> Repo.insert()

      # Initialize test session and simulate Pow session authentication
      conn = Plug.Test.init_test_session(conn, %{})
      conn = Pow.Plug.assign_current_user(conn, user, otp_app: :xiam)
      
      # Set up a simple LiveView to mount the component
      {:ok, view, _html} = live_isolated(conn, XIAMWeb.Live.Components.PasskeyComponentTest.TestPasskeyLiveView)
      
      %{view: view, user: user}
    end
    
    @tag :skip
    test "renders the passkey registration form", %{view: view} do
      html = render(view)
      assert html =~ "Register a New Passkey"
      assert html =~ "Friendly Name"
      assert html =~ "Register Passkey"
    end
    
    @tag :skip
    test "displays registered passkeys", %{view: view, user: user} do
      # Create some passkeys for the user
      {:ok, _passkey1} = Repo.insert(%UserPasskey{
        user_id: user.id,
        credential_id: <<1, 2, 3, 4>>,
        public_key: <<10, 11, 12, 13>>,
        sign_count: 0,
        friendly_name: "Test Passkey 1"
      })
      
      {:ok, _passkey2} = Repo.insert(%UserPasskey{
        user_id: user.id,
        credential_id: <<5, 6, 7, 8>>,
        public_key: <<10, 11, 12, 13>>,
        sign_count: 0,
        friendly_name: "Test Passkey 2"
      })
      
      # Refresh the component to show passkeys
      html = render_click(view, "load-passkeys")
      
      # Verify both passkeys are displayed
      assert html =~ "Test Passkey 1"
      assert html =~ "Test Passkey 2"
    end
    
    @tag :skip
    test "clicking register button shows confirmation", %{view: view} do
      # This test is limited since we cannot mock the WebAuthn API calls in JS
      # We can just verify the UI flow
      html = render_click(view, "prepare-registration")
      assert html =~ "Registering Passkey"
      assert html =~ "Please follow the browser prompts to complete registration"
    end
  end
  
  # A simple LiveView for testing the component
  defmodule TestPasskeyLiveView do
    use Phoenix.LiveView, layout: {XIAMWeb.Layouts, :app}
    
    def __live__() do
      %{kind: :component, module: __MODULE__, layout: false}
    end
    
    def mount(_params, _session, socket) do
      user = Pow.Plug.current_user(socket, otp_app: :xiam)
      {:ok, assign(socket, current_user: user)}
    end
    
    def render(assigns) do
      ~H"""
      <div>
        <.live_component 
          module={XIAMWeb.Live.Components.PasskeyComponent} 
          id="passkey-test" 
          current_user={@current_user} 
        />
      </div>
      """
    end
    
    def handle_event("load-passkeys", _, socket) do
      send_update(XIAMWeb.Live.Components.PasskeyComponent, id: "passkey-test", action: :load)
      {:noreply, socket}
    end
    
    def handle_event("prepare-registration", _, socket) do
      send_update(XIAMWeb.Live.Components.PasskeyComponent, id: "passkey-test", action: :register)
      {:noreply, socket}
    end
  end
end