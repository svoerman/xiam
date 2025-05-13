defmodule XIAMWeb.Admin.SettingsLiveTest do
  use XIAMWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
    
    alias XIAM.System.Setting
  alias XIAM.Repo

  # Create proper admin user for tests with required capabilities
  defp create_admin_user() do
    # Create a mock role with admin capabilities - specifically include admin_access
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    mock_role = %Xiam.Rbac.Role{
      name: "Admin Role",
      description: "Admin role for tests",
      inserted_at: now,
      updated_at: now
    }
    inserted_role = Repo.insert!(mock_role)
    %XIAM.Users.User{
      email: "admin_#{System.system_time(:millisecond)}@example.com",
      role_id: inserted_role.id,
      inserted_at: now,
      updated_at: now
    }
  end

  # Setup helper to create a consistent mock for Repo.preload
    defp login(conn, user) do
    # Using Pow's test helpers with explicit config and init_test_session
    pow_config = [otp_app: :xiam]
    conn
    |> init_test_session(%{})
    |> Pow.Plug.assign_current_user(user, pow_config)
  end

  setup %{conn: conn} do
    # Ensure proper ETS tables exist
    XIAM.ETSTestHelper.ensure_ets_tables_exist()
    

    # Create admin user with proper capabilities
    admin_user = create_admin_user()
    inserted_admin = Repo.insert!(admin_user)

    # Set up conn for LiveView tests with required options
    conn = %{conn |
             private: Map.put(conn.private, :phoenix_endpoint, XIAMWeb.Endpoint),
             owner: self()}

    # Authenticate user
    conn = login(conn, inserted_admin)

    # Create test settings with unique identifiers to prevent conflicts
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    # Clear all settings to avoid unique constraint errors
    Repo.delete_all(Setting)
    settings = %{
      "application_name" => %Setting{
        key: "application_name",
        value: "XIAM Test",
        data_type: "string",
        inserted_at: now,
        updated_at: now
      },
      "allow_registration" => %Setting{
        key: "allow_registration",
        value: "true",
        data_type: "boolean",
        inserted_at: now,
        updated_at: now
      }
    }
    Enum.each(settings, fn {_k, v} -> Repo.insert!(v) end)

    # (Removed unused min_password_key and timestamp)
    
    {:ok, 
      conn: conn
    }
  end

  describe "Settings LiveView" do
    test "displays general settings by default", %{conn: conn} do
      # Use resilient pattern for LiveView rendering
      XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        {:ok, _view, html} = live(conn, ~p"/admin/settings")

        # Verify the page title and general settings are shown
        assert html =~ "System Settings"
        assert html =~ "General Settings"
        assert html =~ "Application Name"
        assert html =~ "XIAM Test"
        assert html =~ "Allow Registration"
      end, max_retries: 3, retry_delay: 200)
    end

    test "can navigate to different tabs", %{conn: conn} do
      # Use resilient pattern for LiveView rendering
      XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        {:ok, view, _html} = live(conn, ~p"/admin/settings")

        # Test navigation to each tab
        for tab <- ["oauth", "mfa", "security"] do
          view |> element("#tab-#{tab}") |> render_click()
          assert render(view) =~ String.capitalize(tab)
        end
      end, max_retries: 3, retry_delay: 200)
    end

    test "can update a boolean setting", %{conn: conn} do
      # Use resilient pattern for LiveView rendering
      XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
        {:ok, view, _html} = live(conn, ~p"/admin/settings")

        # Find and click the edit button for our boolean setting
        view 
        |> element("button[phx-value-key='allow_registration']") 
        |> render_click()

        # Verify modal is shown
        assert has_element?(view, "h3", "Edit Setting")

        # Toggle the boolean value and save
        view
        |> element("form")
        |> render_submit(%{"setting" => %{"value" => "false"}})

        # Verify success message appears
        assert render(view) =~ "Setting updated successfully"
      end, max_retries: 3, retry_delay: 200)
    end
  end
end
