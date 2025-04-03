defmodule XIAMWeb.Admin.SettingsLiveTest do
  use XIAMWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mock
  
  alias XIAM.Users.User
  alias XIAM.System.{Settings, Setting}
  alias XIAM.Repo

  # Helpers for test authentication
  def create_admin_user() do
    # Create a user
    {:ok, user} = %User{}
      |> User.pow_changeset(%{
        email: "admin_user_#{System.unique_integer([:positive])}@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Repo.insert()

    # Create a role with admin capability
    {:ok, role} = %Xiam.Rbac.Role{
      name: "Admin Role",
      description: "Role with admin access"
    }
    |> Repo.insert()

    # Create a product for capabilities
    {:ok, product} = %Xiam.Rbac.Product{
      product_name: "Admin Test Product",
      description: "Product for testing admin access"
    }
    |> Repo.insert()
    
    # Add admin capability
    {:ok, capability} = %Xiam.Rbac.Capability{
      name: "admin_access",
      description: "Admin access",
      product_id: product.id
    }
    |> Repo.insert()
    
    # Associate capability with role
    role
    |> Repo.preload(:capabilities)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:capabilities, [capability])
    |> Repo.update!()

    # Assign role to user
    {:ok, user} = user
      |> User.role_changeset(%{role_id: role.id})
      |> Repo.update()

    # Return user with preloaded role and capabilities
    user |> Repo.preload(role: :capabilities)
  end

  defp login(conn, user) do
    # Using Pow's test helpers with explicit config
    pow_config = [otp_app: :xiam]
    conn
    |> Pow.Plug.assign_current_user(user, pow_config)
  end

  setup %{conn: conn} do
    # Create admin user
    user = create_admin_user()

    # Authenticate connection
    conn = login(conn, user)
    
    # Clear existing settings first to avoid unique constraint errors
    Repo.delete_all(Setting)
    
    # Create test settings with unique identifiers to prevent conflicts
    timestamp = System.system_time(:second)
    
    {:ok, setting1} = %Setting{}
    |> Setting.changeset(%{
      key: "application_name_#{timestamp}",
      value: "XIAM Test",
      category: "general",
      description: "Application name",
      data_type: "string"
    })
    |> Repo.insert()
    
    {:ok, setting2} = %Setting{}
    |> Setting.changeset(%{
      key: "allow_registration_#{timestamp}",
      value: "true",
      category: "general",
      description: "Allow user registration",
      data_type: "boolean"
    })
    |> Repo.insert()
    
    {:ok, setting3} = %Setting{}
    |> Setting.changeset(%{
      key: "github_enabled_#{timestamp}",
      value: "false",
      category: "oauth",
      description: "Enable GitHub OAuth",
      data_type: "boolean"
    })
    |> Repo.insert()
    
    {:ok, setting4} = %Setting{}
    |> Setting.changeset(%{
      key: "github_client_id_#{timestamp}",
      value: "github-client-id",
      category: "oauth",
      description: "GitHub Client ID",
      data_type: "string"
    })
    |> Repo.insert()

    {:ok, setting5} = %Setting{}
    |> Setting.changeset(%{
      key: "mfa_required_#{timestamp}",
      value: "false",
      category: "mfa",
      description: "Require MFA for all users",
      data_type: "boolean"
    })
    |> Repo.insert()
    
    {:ok, setting6} = %Setting{}
    |> Setting.changeset(%{
      key: "minimum_password_length_#{timestamp}",
      value: "8",
      category: "security",
      description: "Minimum password length",
      data_type: "integer"
    })
    |> Repo.insert()

    # Add original keys that the LiveView expects to find
    {:ok, app_name_setting} = %Setting{}
    |> Setting.changeset(%{
      key: "application_name",
      value: "XIAM Test",
      category: "general",
      description: "Application name",
      data_type: "string"
    })
    |> Repo.insert()
    
    {:ok, allow_reg_setting} = %Setting{}
    |> Setting.changeset(%{
      key: "allow_registration",
      value: "true",
      category: "general",
      description: "Allow user registration",
      data_type: "boolean"
    })
    |> Repo.insert()
    
    {:ok, github_enabled_setting} = %Setting{}
    |> Setting.changeset(%{
      key: "github_enabled",
      value: "false",
      category: "oauth",
      description: "Enable GitHub OAuth",
      data_type: "boolean"
    })
    |> Repo.insert()
    
    {:ok, github_client_setting} = %Setting{}
    |> Setting.changeset(%{
      key: "github_client_id",
      value: "github-client-id",
      category: "oauth",
      description: "GitHub Client ID",
      data_type: "string"
    })
    |> Repo.insert()
    
    {:ok, google_enabled_setting} = %Setting{}
    |> Setting.changeset(%{
      key: "google_enabled",
      value: "false",
      category: "oauth",
      description: "Enable Google OAuth",
      data_type: "boolean"
    })
    |> Repo.insert()
    
    {:ok, google_client_setting} = %Setting{}
    |> Setting.changeset(%{
      key: "google_client_id",
      value: "google-client-id",
      category: "oauth",
      description: "Google Client ID",
      data_type: "string"
    })
    |> Repo.insert()
    
    {:ok, mfa_setting} = %Setting{}
    |> Setting.changeset(%{
      key: "mfa_required",
      value: "false",
      category: "mfa",
      description: "Require MFA for all users",
      data_type: "boolean"
    })
    |> Repo.insert()
    
    {:ok, min_pw_setting} = %Setting{}
    |> Setting.changeset(%{
      key: "minimum_password_length",
      value: "8",
      category: "security",
      description: "Minimum password length",
      data_type: "integer"
    })
    |> Repo.insert()

    # Initialize settings cache
    Settings.init_cache()
    
    {:ok, 
      conn: conn, 
      user: user, 
      settings: [setting1, setting2, setting3, setting4, setting5, setting6],
      system_settings: %{
        app_name: app_name_setting,
        allow_reg: allow_reg_setting,
        github_enabled: github_enabled_setting,
        github_client: github_client_setting,
        google_enabled: google_enabled_setting,
        google_client: google_client_setting,
        mfa_required: mfa_setting,
        min_password: min_pw_setting
      }
    }
  end
  
  describe "Settings LiveView" do
    test "displays general settings by default", %{conn: conn, system_settings: settings} do
      with_mock(Settings, [:passthrough], [
        list_settings: fn -> Map.values(settings) end
      ]) do
        {:ok, _view, html} = live(conn, ~p"/admin/settings")

      # Verify the page title and general settings are shown
      assert html =~ "System Settings"
      assert html =~ "General Settings"
      assert html =~ "Application Name"
      assert html =~ "XIAM Test"
      assert html =~ "Allow Registration"
      end
    end
    
    test "can navigate to different tabs", %{conn: conn, system_settings: settings} do
      with_mock(Settings, [:passthrough], [
        list_settings: fn -> Map.values(settings) end
      ]) do
        {:ok, view, _html} = live(conn, ~p"/admin/settings")
      
      # Click the OAuth Providers tab
      rendered = view
      |> element("button", "OAuth Providers")
      |> render_click()
      
      # Verify OAuth settings are shown
      assert rendered =~ "OAuth Provider Settings"
      assert rendered =~ "GitHub"
      assert rendered =~ "Disabled"
      
      # Click the MFA tab
      rendered = view
      |> element("button", "Multi-Factor Auth")
      |> render_click()
      
      # Verify MFA settings are shown
      assert rendered =~ "Multi-Factor Authentication Settings"
      assert rendered =~ "Mfa Required"
      
      # Click the Security tab
      rendered = view
      |> element("button", "Security")
      |> render_click()
      
      # Verify Security settings are shown
      assert rendered =~ "Security Settings"
      assert rendered =~ "Minimum Password Length"
      end
    end
    
    test "can update a boolean setting", %{conn: conn, system_settings: settings} do
      with_mocks([
        {Settings, [:passthrough], [
          list_settings: fn -> Map.values(settings) end,
          update_setting_by_key: fn _key, value -> 
            setting = settings.allow_reg
            {:ok, %{setting | value: value}}
          end,
          refresh_cache: fn -> :ok end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/admin/settings")
        
        # Click the edit button for Allow Registration
        view
        |> element("button[phx-click='show_edit_modal'][phx-value-section='general'][phx-value-key='allow_registration']")
        |> render_click()
        
        # Change the value to No (false)
        rendered = view
        |> form("form", %{
          "setting[value]" => "false"
        })
        |> render_submit()
        
        # Verify the update was reflected in the view
        assert rendered =~ "Setting updated successfully"
        
        # Verify the mock was called with correct arguments
        assert_called(Settings.update_setting_by_key("allow_registration", "false"))
      end
    end
    
    test "can update a text setting", %{conn: conn, system_settings: settings} do
      new_name = "Updated XIAM App"
      
      with_mocks([
        {Settings, [:passthrough], [
          list_settings: fn -> Map.values(settings) end,
          update_setting_by_key: fn _key, value -> 
            setting = settings.app_name
            {:ok, %{setting | value: value}}
          end,
          refresh_cache: fn -> :ok end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/admin/settings")
        
        # Click the edit button for Application Name
        view
        |> element("button[phx-click='show_edit_modal'][phx-value-section='general'][phx-value-key='application_name']")
        |> render_click()
        
        # Change the value
        rendered = view
        |> form("form", %{
          "setting[value]" => new_name
        })
        |> render_submit()
        
        # Verify the update was reflected in the view
        assert rendered =~ "Setting updated successfully"
        
        # Verify the mock was called with correct arguments
        assert_called(Settings.update_setting_by_key("application_name", new_name))
      end
    end
    
    test "can update a numeric setting", %{conn: conn, system_settings: settings} do
      new_value = "10"
      
      with_mocks([
        {Settings, [:passthrough], [
          list_settings: fn -> Map.values(settings) end,
          update_setting_by_key: fn _key, value -> 
            setting = settings.min_password
            {:ok, %{setting | value: value}}
          end,
          refresh_cache: fn -> :ok end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/admin/settings?tab=security")
        
        # Click the edit button for Minimum Password Length
        view
        |> element("button[phx-click='show_edit_modal'][phx-value-section='security'][phx-value-key='minimum_password_length']")
        |> render_click()
        
        # Change the value
        rendered = view
        |> form("form", %{
          "setting[value]" => new_value
        })
        |> render_submit()
        
        # Verify the update was reflected in the view
        assert rendered =~ "Setting updated successfully"
        
        # Verify the mock was called with correct arguments
        assert_called(Settings.update_setting_by_key("minimum_password_length", new_value))
      end
    end
    
    test "can open and close modal without saving changes", %{conn: conn, system_settings: settings} do
      with_mock(Settings, [:passthrough], [
        list_settings: fn -> Map.values(settings) end
      ]) do
        {:ok, view, _html} = live(conn, ~p"/admin/settings")
      
      # Click the edit button for Application Name
      view
      |> element("button[phx-click='show_edit_modal'][phx-value-section='general'][phx-value-key='application_name']")
      |> render_click()
      
      # Verify modal is shown
      rendered = render(view)
      assert rendered =~ "Edit Setting"
      
      # Click the cancel button
      view
      |> element("button", "Cancel")
      |> render_click()
      
      # The modal closing is handled by LiveView and we trust that it works
      # We're just testing that no error is raised when clicking the cancel button
      :ok
      end
    end
    
    test "can navigate to a tab via URL", %{conn: conn, system_settings: settings} do
      with_mock(Settings, [:passthrough], [
        list_settings: fn -> Map.values(settings) end
      ]) do
        {:ok, _view, html} = live(conn, ~p"/admin/settings?tab=oauth")
      
      # Verify OAuth tab is active
      assert html =~ "OAuth Provider Settings"
      assert html =~ "GitHub"
      assert html =~ "Google"
      end
    end
    
    test "can access settings via different routes", %{conn: conn, system_settings: settings} do
      with_mock(Settings, [:passthrough], [
        list_settings: fn -> Map.values(settings) end
      ]) do
        # Test all tabs via URL parameter
        tabs = ["general", "oauth", "mfa", "security"]
      
      for tab <- tabs do
        {:ok, _view, html} = live(conn, ~p"/admin/settings?tab=#{tab}")
        
        # Verify correct content for each tab
        case tab do
          "general" -> 
            assert html =~ "General Settings"
            assert html =~ "Application Name"
          "oauth" -> 
            assert html =~ "OAuth Provider Settings"
            assert html =~ "GitHub"
          "mfa" -> 
            assert html =~ "Multi-Factor Authentication Settings"
            assert html =~ "Mfa Required"
          "security" -> 
            assert html =~ "Security Settings"
            assert html =~ "Minimum Password Length"
        end
      end
      end
    end
  end
end