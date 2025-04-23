defmodule XIAMWeb.Admin.GDPRLiveTest do
  use XIAMWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mock

  alias XIAM.Users.User
  alias XIAM.Repo

  # Helper for test authentication
  def create_admin_user() do
    # Create a user
    {:ok, user} = %User{}
      |> User.pow_changeset(%{
        email: "gdpr_admin_user@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Repo.insert()

    # Create a role with admin capability
    {:ok, role} = %Xiam.Rbac.Role{
      name: "GDPR Admin Role",
      description: "Role with admin access"
    }
    |> Repo.insert()

    # Create a product for capabilities
    {:ok, product} = %Xiam.Rbac.Product{
      product_name: "GDPR Test Product",
      description: "Product for testing GDPR admin access"
    }
    |> Repo.insert()

    # Add admin capabilities
    {:ok, gdpr_capability} = %Xiam.Rbac.Capability{
      name: "admin_gdpr_access",
      description: "Admin GDPR access capability",
      product_id: product.id
    }
    |> Repo.insert()

    # Add generic admin access capability (required by AdminAuthPlug)
    {:ok, admin_capability} = %Xiam.Rbac.Capability{
      name: "admin_access",
      description: "General admin access capability",
      product_id: product.id
    }
    |> Repo.insert()

    # Associate capabilities with role
    role
    |> Repo.preload(:capabilities)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:capabilities, [gdpr_capability, admin_capability])
    |> Repo.update!()

    # Assign role to user
    {:ok, user} = user
      |> User.role_changeset(%{role_id: role.id})
      |> Repo.update()

    # Return user with preloaded role and capabilities
    user |> Repo.preload(role: :capabilities)
  end

  # Create another test user
  def create_test_user() do
    {:ok, user} = %User{}
      |> User.pow_changeset(%{
        email: "gdpr_test_user@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Repo.insert()

    user
  end

  defp login(conn, user) do
    # Using Pow's test helpers with explicit config
    pow_config = [otp_app: :xiam]
    conn
    |> Pow.Plug.assign_current_user(user, pow_config)
  end

  describe "GDPR LiveView" do
    setup %{conn: conn} do
      # Create admin user
      admin_user = create_admin_user() |> XIAM.Repo.preload(:role)

      # Create a test user to manage in GDPR
      test_user = create_test_user()

      # Authenticate connection
      conn = login(conn, admin_user)

      # Return authenticated connection and users
      {:ok, conn: conn, admin_user: admin_user, test_user: test_user}
    end

    test "mounts successfully", %{conn: conn, admin_user: admin_user} do
      get_by_mock = fn User, query_opts ->
        case Keyword.fetch(query_opts, :id) do
          {:ok, id} when id == admin_user.id -> admin_user
          _ -> nil
        end
      end

      with_mocks([
        {XIAM.Consent, [], [list_consent_types: fn -> [] end]},
        {XIAM.Repo, [], [
          all: fn _query -> [] end,
          get_by: get_by_mock
        ]}
      ]) do
        {:ok, _view, html} = live(conn, ~p"/admin/gdpr")

        # Verify page title is set correctly
        assert html =~ "GDPR Compliance Management"
        assert html =~ "Manage user consent, data portability, and the right to be forgotten"
      end
    end

    test "displays user selection panel", %{conn: conn, admin_user: admin_user} do
      get_by_mock = fn User, query_opts ->
        case Keyword.fetch(query_opts, :id) do
          {:ok, id} when id == admin_user.id -> admin_user
          _ -> nil
        end
      end

      with_mocks([
        {XIAM.Consent, [], [list_consent_types: fn -> [] end]},
        {XIAM.Repo, [], [
          all: fn _query -> [] end,
          get_by: get_by_mock
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/admin/gdpr")

        # Verify user selection panel exists
        assert has_element?(view, "h2", "Select User")
        assert has_element?(view, "label", "Select a user:")
        assert has_element?(view, "select#user_select")
      end
    end

    test "handles theme toggle", %{conn: conn, admin_user: admin_user} do
      get_by_mock = fn User, query_opts ->
        case Keyword.fetch(query_opts, :id) do
          {:ok, id} when id == admin_user.id -> admin_user
          _ -> nil
        end
      end

      with_mocks([
        {XIAM.Consent, [], [list_consent_types: fn -> [] end]},
        {XIAM.Repo, [], [
          all: fn _query -> [] end,
          get_by: get_by_mock
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/admin/gdpr")

        # Send the toggle_theme event
        result = view |> render_hook("toggle_theme")
        assert result =~ "GDPR Compliance Management"
      end
    end

    test "redirects anonymous users to login", %{} do
      # Create a non-authenticated connection
      anon_conn = build_conn()

      # Try to access the GDPR page
      conn = get(anon_conn, ~p"/admin/gdpr")

      # Should redirect to login page
      assert redirected_to(conn) =~ ~p"/session/new"
    end

    test "selects a user and displays their management panel", %{conn: conn, admin_user: admin_user, test_user: test_user} do
      get_by_mock = fn User, query_opts ->
        case Keyword.fetch(query_opts, :id) do
          {:ok, id} when id == admin_user.id -> admin_user
          {:ok, id} when id == test_user.id -> test_user
          _ -> nil
        end
      end

      with_mocks([
        {XIAM.Consent, [], [
          list_consent_types: fn -> [] end,
          get_user_consents: fn _user_id -> [] end
        ]},
        {XIAM.Repo, [], [
          all: fn _query -> [test_user] end,
          get: fn User, id when id == test_user.id -> test_user end,
          get_by: get_by_mock
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/admin/gdpr")

        # Submit the form directly since phx-change is on the form, not the select
        view
        |> form("form", %{id: test_user.id})
        |> render_change()

        # Verify we're redirected to the user-specific URL
        assert_patched(view, ~p"/admin/gdpr?user_id=#{test_user.id}")
      end
    end

    test "selecting empty user redirects to base URL", context do
      %{conn: conn, admin_user: admin_user} = context

      # Define mock outside to capture context
      get_by_mock = fn User, query_opts ->
        case Keyword.fetch(query_opts, :id) do
          {:ok, id} when id == admin_user.id -> admin_user
          _ -> nil
        end
      end

      with_mocks([
        {XIAM.Consent, [], [list_consent_types: fn -> [] end]},
        {XIAM.Repo, [], [
          all: fn _query -> [] end,
          get_by: get_by_mock
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/admin/gdpr")

        # Submit the form directly
        view
        |> form("form", %{id: ""})
        |> render_change()

        # Verify we're redirected to the base URL
        assert_patched(view, ~p"/admin/gdpr")
      end
    end

    test "displays export data modal and handles export", %{conn: conn, admin_user: admin_user, test_user: test_user} do
      get_by_mock = fn User, query_opts ->
        case Keyword.fetch(query_opts, :id) do
          {:ok, id} when id == admin_user.id -> admin_user
          {:ok, id} when id == test_user.id -> test_user
          _ -> nil
        end
      end

      with_mocks([
        {XIAM.Consent, [], [
          list_consent_types: fn -> [] end,
          get_user_consents: fn _user_id -> [] end
        ]},
        {XIAM.GDPR.DataPortability, [], [
          export_user_data: fn _user_id -> %{"user" => %{"email" => test_user.email}} end
        ]},
        {XIAM.Repo, [], [
          all: fn _query -> [test_user] end,
          get: fn User, id when id == test_user.id -> test_user end,
          get_by: get_by_mock
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/admin/gdpr?user_id=#{test_user.id}")

        # Click export button
        view
        |> element("button", "Export User Data")
        |> render_click()

        # Verify modal is shown
        assert has_element?(view, "h3", "User Data Export")
        assert has_element?(view, "button", "Generate Export")

        # Click generate export button
        view
        |> element("button", "Generate Export")
        |> render_click()

        # Verify export data is shown
        assert view |> has_element?("pre")
        assert view |> has_element?("a", "Download JSON")
      end
    end

    test "displays consent modal", %{conn: conn, admin_user: admin_user, test_user: test_user} do
      get_by_mock = fn User, query_opts ->
        case Keyword.fetch(query_opts, :id) do
          {:ok, id} when id == admin_user.id -> admin_user
          {:ok, id} when id == test_user.id -> test_user
          _ -> nil
        end
      end

      with_mocks([
        {XIAM.Consent, [], [
          list_consent_types: fn -> [%{id: 1, name: "Marketing"}] end,
          get_user_consents: fn _user_id -> [] end
        ]},
        {XIAM.Repo, [], [
          all: fn _query -> [test_user] end,
          get: fn User, id when id == test_user.id -> test_user end,
          get_by: get_by_mock
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/admin/gdpr?user_id=#{test_user.id}")

        # Click manage consent button
        view
        |> element("button", "Manage Consent")
        |> render_click()

        # Verify modal is shown
        assert has_element?(view, "h3", "Manage User Consent")
        assert has_element?(view, "select#consent_type")
        assert has_element?(view, "select#consent_status")
      end
    end

    test "handles consent form validation", %{conn: conn, admin_user: admin_user, test_user: test_user} do
      get_by_mock = fn User, query_opts ->
        case Keyword.fetch(query_opts, :id) do
          {:ok, id} when id == admin_user.id -> admin_user
          {:ok, id} when id == test_user.id -> test_user
          _ -> nil
        end
      end

      with_mocks([
        {XIAM.Consent, [], [
          list_consent_types: fn -> [%{id: 1, name: "Marketing"}] end,
          get_user_consents: fn _user_id -> [] end
        ]},
        {XIAM.Repo, [], [
          all: fn _query -> [test_user] end,
          get: fn User, id when id == test_user.id -> test_user end,
          get_by: get_by_mock
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/admin/gdpr?user_id=#{test_user.id}")

        # Click manage consent button
        view
        |> element("button", "Manage Consent")
        |> render_click()

        # Test validate_consent event handler
        assert view
        |> render_change("validate_consent", %{}) =~ "Manage User Consent"
      end
    end

    test "displays anonymize modal and handles anonymization", %{conn: conn, admin_user: admin_user, test_user: test_user} do
      get_by_mock = fn User, query_opts ->
        case Keyword.fetch(query_opts, :id) do
          {:ok, id} when id == admin_user.id -> admin_user
          {:ok, id} when id == test_user.id -> test_user
          _ -> nil
        end
      end

      with_mocks([
        {XIAM.Consent, [], [
          list_consent_types: fn -> [] end,
          get_user_consents: fn _user_id -> [] end
        ]},
        {XIAM.GDPR.DataRemoval, [], [
          anonymize_user: fn _user_id -> {:ok, test_user} end
        ]},
        {XIAM.Repo, [], [
          all: fn _query -> [test_user] end,
          get: fn User, id when id == test_user.id -> test_user end,
          get_by: get_by_mock
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/admin/gdpr?user_id=#{test_user.id}")

        # Click anonymize button
        view
        |> element("button", "Anonymize User Data")
        |> render_click()

        # Verify modal is shown
        assert has_element?(view, "h3", "Anonymize User Data")
        assert has_element?(view, "button", "Confirm Anonymization")

        # Click confirm button
        view
        |> element("button", "Confirm Anonymization")
        |> render_click()

        # Verify redirect
        assert_patched(view, ~p"/admin/gdpr")
      end
    end

    test "displays delete modal and handles deletion", %{conn: conn, admin_user: admin_user, test_user: test_user} do
      get_by_mock = fn User, query_opts ->
        case Keyword.fetch(query_opts, :id) do
          {:ok, id} when id == admin_user.id -> admin_user
          {:ok, id} when id == test_user.id -> test_user
          _ -> nil
        end
      end

      with_mocks([
        {XIAM.Consent, [], [
          list_consent_types: fn -> [] end,
          get_user_consents: fn _user_id -> [] end
        ]},
        {XIAM.GDPR.DataRemoval, [], [
          delete_user: fn _user_id -> {:ok, test_user.id} end
        ]},
        {XIAM.Repo, [], [
          all: fn _query -> [test_user] end,
          get: fn User, id when id == test_user.id -> test_user end,
          get_by: get_by_mock,
          delete: fn user when user.id == test_user.id -> {:ok, test_user} end # Mock Repo.delete/1
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/admin/gdpr?user_id=#{test_user.id}")

        # Click delete button
        view
        |> element("button", "Delete User Completely")
        |> render_click()

        # Verify modal is shown
        assert has_element?(view, "h3", "Delete User")
        assert has_element?(view, "button", "Permanently Delete User")

        # Click confirm deletion button
        view
        |> element("button", "Permanently Delete User")
        |> render_click()

        # Verify redirect
        assert_patched(view, ~p"/admin/gdpr")
      end
    end

    test "handles modal closing", %{conn: conn, admin_user: admin_user, test_user: test_user} do
      get_by_mock = fn User, query_opts ->
        case Keyword.fetch(query_opts, :id) do
          {:ok, id} when id == admin_user.id -> admin_user
          {:ok, id} when id == test_user.id -> test_user
          _ -> nil
        end
      end

      with_mocks([
        {XIAM.Consent, [], [
          list_consent_types: fn -> [] end,
          get_user_consents: fn _user_id -> [] end
        ]},
        {XIAM.Repo, [], [
          all: fn _query -> [test_user] end,
          get: fn User, id when id == test_user.id -> test_user end,
          get_by: get_by_mock
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/admin/gdpr?user_id=#{test_user.id}")

        # Open modal
        view
        |> element("button", "Export User Data")
        |> render_click()

        # Verify modal is shown
        assert has_element?(view, "h3", "User Data Export")

        # Close modal
        view
        |> element("button[phx-click='close_modal']")
        |> render_click()

        # Verify modal is closed
        refute has_element?(view, "h3", "User Data Export")
      end
    end

    test "handles invalid user ID in URL", %{conn: conn, admin_user: admin_user} do
      get_by_mock = fn User, query_opts ->
        case Keyword.fetch(query_opts, :id) do
          {:ok, id} when id == admin_user.id -> admin_user
          _ -> nil
        end
      end

      with_mocks([
        {XIAM.Consent, [], [list_consent_types: fn -> [] end]},
        {XIAM.Repo, [], [
          all: fn _query -> [] end,
          get: fn User, _id -> nil end,
          get_by: get_by_mock
        ]}
      ]) do
        # We need to match the redirect explicitly since live/3 will follow redirects
        assert {:error, {:live_redirect, %{to: "/admin/gdpr", flash: %{"error" => "User not found"}}}} =
          live(conn, ~p"/admin/gdpr?user_id=999999")
      end
    end

    test "submits consent form", %{conn: conn, admin_user: admin_user, test_user: test_user} do
      consent_type_id = 1
      consent_type = %{id: consent_type_id, name: "Marketing"}

      get_by_mock = fn User, query_opts ->
        case Keyword.fetch(query_opts, :id) do
          {:ok, id} when id == admin_user.id -> admin_user
          {:ok, id} when id == test_user.id -> test_user
          _ -> nil
        end
      end

      with_mocks([
        {XIAM.Consent, [], [
          list_consent_types: fn -> [consent_type] end,
          get_user_consents: fn _user_id -> [] end,
          record_consent: fn _user_id, _type_id, _status -> {:ok, %{consent_type: "Marketing", consent_given: true}} end
        ]},
        {XIAM.Repo, [], [
          all: fn _query -> [test_user] end,
          get: fn User, id when id == test_user.id -> test_user end,
          get_by: get_by_mock
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/admin/gdpr?user_id=#{test_user.id}")

        # Click manage consent button
        view
        |> element("button", "Manage Consent")
        |> render_click()

        # Submit the consent form
        view
        |> form("form[phx-submit='save_consent']", %{
          "consent" => %{
            "consent_type" => consent_type_id,
            "consent_given" => "true"
          }
        })
        |> render_submit()

        # Verify modal is closed (assertion based on the fact that save_consent should assign show_consent_modal: false)
        refute has_element?(view, "h3", "Manage User Consent")
      end
    end
  end
end
