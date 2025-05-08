defmodule XIAMWeb.Admin.SettingsLiveTest do
  use XIAMWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Mock
  import XIAM.ETSTestHelper

  alias XIAM.Users.User
  alias XIAM.System.{Settings, Setting}
  alias XIAM.Repo

  # Create proper admin user for tests with required capabilities
  defp create_admin_user() do
    # Create a mock role with admin capabilities - specifically include admin_access
    mock_role = %Xiam.Rbac.Role{
      id: "role_#{System.system_time(:millisecond)}_#{:rand.uniform(100_000)}",
      name: "Admin Role",
      description: "Admin role for tests",
      capabilities: [
        # IMPORTANT: This name MUST be exactly "admin_access" to pass the AdminAuthPlug
        %Xiam.Rbac.Capability{id: 1, name: "admin_access"},
        %Xiam.Rbac.Capability{id: 2, name: "admin_settings_access"}
      ],
      inserted_at: NaiveDateTime.utc_now(),
      updated_at: NaiveDateTime.utc_now()
    }

    # Create admin user with proper role
    %XIAM.Users.User{
      id: "admin_#{System.system_time(:millisecond)}_#{:rand.uniform(100_000)}",
      email: "admin_#{System.system_time(:millisecond)}@example.com",
      role: mock_role,
      role_id: mock_role.id,
      inserted_at: NaiveDateTime.utc_now(),
      updated_at: NaiveDateTime.utc_now()
    }
  end

  # Setup helper to create a consistent mock for Repo.preload
  defp create_preload_mock do
    fn user, preload_opts ->
      case preload_opts do
        [role: :capabilities] ->
          # For role preloads, ensure the role capabilities include admin_access
          admin_capability = %Xiam.Rbac.Capability{
            id: 1,
            name: "admin_access",
            description: "Admin access capability",
            product_id: 1,
            inserted_at: NaiveDateTime.utc_now(),
            updated_at: NaiveDateTime.utc_now()
          }

          role = case user.role do
            %Xiam.Rbac.Role{} = role ->
              # Keep the existing struct but update capabilities
              %{role | capabilities: [admin_capability]}
            _ ->
              # Create a new role struct if needed
              %Xiam.Rbac.Role{
                id: user.role_id || 999,
                name: "Admin Role",
                description: "Admin role for tests",
                capabilities: [admin_capability],
                inserted_at: NaiveDateTime.utc_now(),
                updated_at: NaiveDateTime.utc_now()
              }
          end

          %{user | role: role}
        _ -> user
      end
    end
  end

  defp login(conn, user) do
    # Using Pow's test helpers with explicit config and init_test_session
    pow_config = [otp_app: :xiam]
    conn
    |> init_test_session(%{})
    |> Pow.Plug.assign_current_user(user, pow_config)
  end

  setup %{conn: conn} do
    # Ensure proper ETS tables exist
    ensure_ets_tables_exist()
    
    # Explicitly start applications and manage the database connection
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    {:ok, _} = Application.ensure_all_started(:postgrex)
    Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
      
    # Create admin user with proper capabilities
    admin_user = create_admin_user()
    
    # Set up conn for LiveView tests with required options
    conn = %{conn | 
             private: Map.put(conn.private, :phoenix_endpoint, XIAMWeb.Endpoint),
             owner: self()}
    
    # Authenticate user
    conn = login(conn, admin_user)

    # Create test settings with unique identifiers to prevent conflicts
    timestamp = System.system_time(:second)
    
    # First clear existing settings to avoid unique constraint errors
    XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
      Repo.delete_all(Setting)
    end)

    # Create general settings
    app_name_key = "application_name_#{timestamp}"
    allow_reg_key = "allow_registration_#{timestamp}"
    
    {:ok, app_name} = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
      %Setting{}
      |> Setting.changeset(%{
        key: app_name_key,
        value: "XIAM Test",
        category: "general",
        description: "Application name",
        data_type: "string"
      })
      |> Repo.insert()
    end)

    {:ok, allow_reg} = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
      %Setting{}
      |> Setting.changeset(%{
        key: allow_reg_key,
        value: "true",
        category: "general",
        description: "Allow user registration",
        data_type: "boolean"
      })
      |> Repo.insert()
    end)

    # Create security settings
    min_password_key = "minimum_password_length_#{timestamp}"
    
    {:ok, min_password} = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
      %Setting{}
      |> Setting.changeset(%{
        key: min_password_key,
        value: "8",
        category: "security",
        description: "Minimum password length",
        data_type: "integer"
      })
      |> Repo.insert()
    end)

    # Create settings map for tests
    settings = %{
      app_name_key => app_name,
      allow_reg_key => allow_reg,
      min_password_key => min_password
    }
    
    {:ok, 
      conn: conn, 
      admin_user: admin_user, 
      system_settings: settings
    }
  end

  describe "Settings LiveView" do
    test "displays general settings by default", %{conn: conn, system_settings: settings, admin_user: admin_user} do
      # Define the mock function for Repo.get_by to return the admin user
      get_by_mock = fn User, query_opts ->
        case Keyword.fetch(query_opts, :id) do
          {:ok, id} when id == admin_user.id -> admin_user
          _ -> nil
        end
      end
      
      # Use with_mocks to mock both Repo and Settings
      with_mocks([
        {Repo, [], [get_by: get_by_mock, preload: create_preload_mock()]},
        {Settings, [:passthrough], [list_settings: fn -> Map.values(settings) end]}
      ]) do
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
    end

    test "can navigate to different tabs", %{conn: conn, system_settings: settings, admin_user: admin_user} do
      # Define the mock function for Repo.get_by to return the admin user
      get_by_mock = fn User, query_opts ->
        case Keyword.fetch(query_opts, :id) do
          {:ok, id} when id == admin_user.id -> admin_user
          _ -> nil
        end
      end
      
      # Use with_mocks to mock both Repo and Settings
      with_mocks([
        {Repo, [], [get_by: get_by_mock, preload: create_preload_mock()]},
        {Settings, [:passthrough], [list_settings: fn -> Map.values(settings) end]}
      ]) do
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
    end

    test "can update a boolean setting", %{conn: conn, system_settings: settings, admin_user: admin_user} do
      # Get the ID of one of our boolean settings
      setting_key = Enum.find_value(settings, fn {key, setting} ->
        if setting.data_type == "boolean", do: key, else: nil
      end)
      setting = settings[setting_key]

      # Define the mock function for Repo.get_by to return the admin user
      get_by_mock = fn
        User, query_opts ->
          case Keyword.fetch(query_opts, :id) do
            {:ok, id} when id == admin_user.id -> admin_user
            _ -> nil
          end
        Setting, [key: ^setting_key] -> setting
      end

      # Use with_mocks to mock necessary functions
      with_mocks([
        {Repo, [], [get_by: get_by_mock, preload: create_preload_mock()]},
        {Settings, [:passthrough], [
          list_settings: fn -> Map.values(settings) end,
          update_setting: fn _, _ -> {:ok, %{setting | value: "false"}} end
        ]}
      ]) do
        # Use resilient pattern for LiveView rendering
        XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
          {:ok, view, _html} = live(conn, ~p"/admin/settings")

          # Find and click the edit button for our boolean setting
          view 
          |> element("button[phx-value-key='#{setting_key}']") 
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
end
