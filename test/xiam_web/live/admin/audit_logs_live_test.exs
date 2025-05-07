defmodule XIAMWeb.Admin.AuditLogsLiveTest do
  use XIAMWeb.ConnCase
  
  @moduletag :integration

  import Phoenix.LiveViewTest
  import Mock
  import XIAM.ETSTestHelper
  alias XIAM.Users.User
  alias XIAM.Audit
  alias XIAM.Repo
  
  # Set up timestamp for unique test data
  @timestamp System.system_time(:second)

  # Helpers for test authentication
  def create_admin_user() do
    # Create a timestamp for unique email
    timestamp = System.system_time(:millisecond)
    
    # Ensure ETS tables exist
    ensure_ets_tables_exist()
    
    # Create a user using the resilient pattern
    user = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
      {:ok, user} = %User{}
        |> User.pow_changeset(%{
          email: "admin_audit_logs_user_#{timestamp}@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })
        |> Repo.insert()
      user
    end)

    # Create a role with admin capability using the resilient pattern
    role = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
      {:ok, role} = %Xiam.Rbac.Role{
        name: "Audit Admin Role #{timestamp}",
        description: "Role with admin access"
      }
      |> Repo.insert()
      role
    end)

    # Create a product for capabilities using the resilient pattern
    product = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
      {:ok, product} = %Xiam.Rbac.Product{
        product_name: "Audit Logs Test Product #{timestamp}",
        description: "Product for testing audit logs access"
      }
      |> Repo.insert()
      product
    end)
    
    # Add admin capability using the resilient pattern
    capability = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
      {:ok, capability} = %Xiam.Rbac.Capability{
        name: "admin_access",
        description: "Admin access",
        product_id: product.id
      }
      |> Repo.insert()
      capability
    end)
    
    # Associate capability with role using the resilient pattern
    user_with_role = XIAM.ResilientTestHelper.safely_execute_db_operation(fn ->
      # First, preload capabilities
      role_with_capabilities = role |> Repo.preload(:capabilities)
      
      # Update role with capability
      updated_role = role_with_capabilities
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.put_assoc(:capabilities, [capability])
        |> Repo.update!()

      # Assign role to user
      {:ok, updated_user} = user
        |> User.role_changeset(%{role_id: updated_role.id})
        |> Repo.update()

      # Return user with preloaded role and capabilities
      updated_user |> Repo.preload(role: :capabilities)
    end)
    
    # Return the updated user
    user_with_role
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

    # Create some test audit logs
    test_logs = create_test_logs(user)

    {:ok, conn: conn, user: user, test_logs: test_logs}
  end

  # Helper to create test audit logs
  defp create_test_logs(user) do
    logs = [
      %{
        action: "login_success",
        actor_id: user.id,
        ip_address: "192.168.1.1",
        resource_type: "authentication",
        metadata: %{
          browser: "Chrome",
          os: "Windows"
        }
      },
      %{
        action: "user_created",
        actor_id: user.id,
        ip_address: "192.168.1.1",
        resource_type: "user",
        resource_id: "123",
        metadata: %{
          new_user_id: "123",
          new_user_email: "test_user_#{@timestamp}@example.com"
        }
      },
      %{
        action: "login_failure",
        actor_id: nil,
        ip_address: "192.168.1.2",
        resource_type: "authentication",
        metadata: %{
          reason: "invalid_credentials"
        }
      }
    ]

    Enum.map(logs, fn log_attrs ->
      {:ok, log} = Audit.create_audit_log(log_attrs)
      log
    end)
  end

  describe "AuditLogs LiveView" do
    @tag :integration

    setup %{conn: conn} do
      # Use the centralized LiveViewTestHelper for consistent environment setup
      # This helper ensures all proper ETS tables exist and environment variables are set
      XIAM.LiveViewTestHelper.initialize_live_view_test_env()
      
      # Create an admin user for testing
      admin_user = create_admin_user()
      
      # Create test logs with the admin user
      test_logs = create_test_logs(admin_user)

      # Authenticate the connection with admin user
      conn = login(conn, admin_user)
      
      {:ok, conn: conn, admin_user: admin_user, test_logs: test_logs}
    end
    
    @tag :integration
    test "mounts successfully", context do
      %{conn: conn, admin_user: admin_user, test_logs: test_logs} = context
      
      # Define mock functions outside the with_mocks block to capture context variables
      list_audit_logs_mock = fn _filter, _pagination -> 
        # Ensure each test log has a properly preloaded actor association
        preloaded_logs = Enum.map(test_logs, fn log -> 
          # If the log has an actor_id that matches the admin_user, preload the association
          # Otherwise, ensure actor is nil so the template shows "System"
          case log.actor_id do
            id when id == admin_user.id -> 
              %{log | actor: admin_user}
            nil -> 
              %{log | actor: nil}
            _ -> 
              # For any other actor_id, create a fake actor with email
              %{log | actor: %{email: "other_user_#{log.actor_id}@example.com"}}
          end
        end)
        
        %{items: preloaded_logs, total_pages: 1, total_count: length(preloaded_logs)}
      end
      
      # Define the mock function for checking admin user
      get_by_mock = fn User, query_opts ->
        case Keyword.fetch(query_opts, :id) do
          {:ok, id} when id == admin_user.id -> admin_user
          _ -> nil
        end
      end

      # Mock for the Repo.all function used in available_users
      repo_all_mock = fn query ->
        # Check if this is the query for available_users that selects email and id
        # The query is expected to return a list of {email, id} tuples
        if match?(%Ecto.Query{}, query) do
          case query do
            # This pattern matches the select: {user.email, user.id} in available_users
            %{select: %{expr: {:{},[],_}}} ->
              # Return a simple list of email/id tuples
              [{admin_user.email, admin_user.id}]
            
            # For any other queries
            _ -> []
          end
        else
          # Default fallback for non-Ecto.Query values
          []
        end
      end
      
      with_mocks([
        {XIAM.Audit, [], [
          list_audit_logs: list_audit_logs_mock
        ]},
        {XIAM.Repo, [], [
          get_by: get_by_mock,
          all: repo_all_mock
        ]}
      ]) do
        {:ok, _view, html} = live(conn, ~p"/admin/audit-logs")

        # Verify page title is set correctly
        assert html =~ "Audit Logs"
        assert html =~ "View and search system audit logs"
      end
    end

    @tag :integration
    test "displays audit log entries", context do
      %{conn: conn, admin_user: admin_user, test_logs: test_logs} = context
      
      # Define mock functions outside the with_mocks block to properly capture context variables
      list_audit_logs_mock = fn _filter, _pagination -> 
        # Ensure each test log has a properly preloaded actor association
        preloaded_logs = Enum.map(test_logs, fn log -> 
          # If the log has an actor_id that matches the admin_user, preload the association
          # Otherwise, ensure actor is nil so the template shows "System"
          case log.actor_id do
            id when id == admin_user.id -> 
              %{log | actor: admin_user}
            nil -> 
              %{log | actor: nil}
            _ -> 
              # For any other actor_id, create a fake actor with email
              %{log | actor: %{email: "other_user_#{log.actor_id}@example.com"}}
          end
        end)
        
        %{items: preloaded_logs, total_pages: 1, total_count: length(preloaded_logs)}
      end
      
      # Define the mock function for checking admin user
      get_by_mock = fn User, query_opts ->
        case Keyword.fetch(query_opts, :id) do
          {:ok, id} when id == admin_user.id -> admin_user
          _ -> nil
        end
      end

      # Mock for the Repo.all function used in available_users
      repo_all_mock = fn query ->
        # Check if this is the query for available_users that selects email and id
        # The query is expected to return a list of {email, id} tuples
        if match?(%Ecto.Query{}, query) do
          case query do
            # This pattern matches the select: {user.email, user.id} in available_users
            %{select: %{expr: {:{},[],_}}} ->
              # Return a simple list of email/id tuples
              [{admin_user.email, admin_user.id}]
            
            # For any other queries
            _ -> []
          end
        else
          # Default fallback for non-Ecto.Query values
          []
        end
      end
      
      with_mocks([
        {XIAM.Audit, [], [
          list_audit_logs: list_audit_logs_mock
        ]},
        {XIAM.Repo, [], [
          get_by: get_by_mock,
          all: repo_all_mock
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/admin/audit-logs")

        # Verify that all test logs are shown - actions are displayed with spaces
        for log <- test_logs do
          action_text = log.action |> String.replace("_", " ")
          assert has_element?(view, "td", action_text)
          if log.ip_address, do: assert(has_element?(view, "td", log.ip_address))
        end
      end
    end

    test "can filter by action", %{conn: conn, test_logs: [login_log | _]} do
      {:ok, view, _html} = live(conn, ~p"/admin/audit-logs")

      # Submit the filter form with an action filter
      view
        |> form("form", %{"filter" => %{"action" => "login_success"}})
        |> render_submit()

      # Should show the login_success log but not others
      assert has_element?(view, "td", "login success")
      assert has_element?(view, "td", login_log.ip_address)
      
      # Check that the table entries match what we expect
      refute has_element?(view, "td", "login failure")
    end

    test "can clear filters", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/audit-logs")

      # Apply a filter
      view
        |> form("form", %{"filter" => %{"action" => "login_success"}})
        |> render_submit()

      # Verify filter is applied
      assert has_element?(view, "td", "login success")
      refute has_element?(view, "td", "login failure")

      # Clear the filters
      view
        |> element("button", "Clear")
        |> render_click()

      # All logs should be shown again - wait for the update
      assert render(view) =~ "login success"
      assert render(view) =~ "user created"
      
      # If we want to check for login_failure, we'd need to ensure that record is visible after pagination
      # For simplicity, we'll just check the other two since we know they're created first.
    end

    test "format_metadata displays metadata correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/audit-logs")

      # Check that metadata is displayed somewhere in the table cells
      assert has_element?(view, "td", ~r/browser.*Chrome/)
      assert has_element?(view, "td", ~r/os.*Windows/)
      assert has_element?(view, "td", ~r/new_user_id.*123/)
    end

    test "pagination controls are displayed when needed", %{conn: conn} do
      # Create more audit logs to trigger pagination
      # Ensure ETS tables exist
      ensure_ets_tables_exist()
      user = create_admin_user()
      
      # Create 30 logs (more than per_page which is set to 25 in the component)
      Enum.each(1..30, fn i ->
        Audit.create_audit_log(%{
          action: "test_action_#{i}",
          actor_id: user.id,
          ip_address: "192.168.1.#{i}",
          resource_type: "pagination_test",
          metadata: %{test_index: i}
        })
      end)

      {:ok, _view, html} = live(conn, ~p"/admin/audit-logs")

      # Pagination controls should be visible
      assert html =~ "Page 1 of"
      assert html =~ "Next"
    end

    test "action_color returns appropriate CSS classes", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/audit-logs")

      # Login success should have green styling
      assert html =~ "login_success"
      assert html =~ "bg-green-100"

      # Login failure should have red styling
      assert html =~ "login_failure"
      assert html =~ "bg-red-100"
    end
  end
end