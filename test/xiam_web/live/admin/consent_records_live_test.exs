defmodule XIAMWeb.Admin.ConsentRecordsLiveTest do
  use XIAMWeb.ConnCase

  import Phoenix.LiveViewTest
  alias XIAM.Users.User
  alias XIAM.Consent.ConsentRecord
  alias XIAM.Repo

  # Helper for test authentication
  def create_admin_user() do
    # Create a user
    {:ok, user} = %User{}
      |> User.pow_changeset(%{
        email: "consent_admin_user@example.com", 
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Repo.insert()

    # Create a role with admin capability
    {:ok, role} = %Xiam.Rbac.Role{
      name: "Consent Admin Role",
      description: "Role with admin access"
    }
    |> Repo.insert()

    # Create a product for capabilities
    {:ok, product} = %Xiam.Rbac.Product{
      product_name: "Consent Test Product",
      description: "Product for testing consent admin access"
    }
    |> Repo.insert()
    
    # Add admin capabilities
    {:ok, consent_capability} = %Xiam.Rbac.Capability{
      name: "admin_consent_access",
      description: "Admin consent access capability",
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
    |> Ecto.Changeset.put_assoc(:capabilities, [consent_capability, admin_capability])
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

  # Helper to create a test consent record
  defp create_consent_record(user) do
    {:ok, consent} = %ConsentRecord{
      user_id: user.id,
      consent_type: "marketing_email",
      consent_given: true,
      ip_address: "127.0.0.1",
      user_agent: "Test Browser"
    }
    |> Repo.insert()
    
    consent
  end

  setup %{conn: conn} do
    # Create admin user
    user = create_admin_user()

    # Authenticate connection
    conn = login(conn, user)

    # Create a test consent record
    consent = create_consent_record(user)

    # Return authenticated connection and user
    {:ok, conn: conn, user: user, consent: consent}
  end

  describe "Consent Records LiveView" do
    test "mounts successfully", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/consents")

      # Verify page title is set correctly
      assert html =~ "Consent Records"
      assert html =~ "Manage and track user consent for GDPR compliance"
    end

    test "displays filter sections", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/consents")

      # Verify filter section elements exist
      assert has_element?(view, "label", "Consent Type")
      assert has_element?(view, "label", "Status")
      assert has_element?(view, "label", "User ID")
      assert has_element?(view, "label", "From Date")
      assert has_element?(view, "label", "To Date")
      
      # Verify filter action buttons
      assert has_element?(view, "button", "Clear Filters")
      assert has_element?(view, "button", "Apply Filters")
    end

    test "displays consent records table", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/consents")

      # Verify table headers exist
      assert has_element?(view, "th", "ID")
      assert has_element?(view, "th", "User")
      assert has_element?(view, "th", "Consent Type")
      assert has_element?(view, "th", "Status")
      assert has_element?(view, "th", "Date Created")
      assert has_element?(view, "th", "Last Modified")
      assert has_element?(view, "th", "Actions")
    end

    test "displays consent record data", %{conn: conn, consent: consent, user: user} do
      {:ok, view, _html} = live(conn, ~p"/admin/consents")

      # Verify consent record appears in table
      assert has_element?(view, "td", Integer.to_string(consent.id))
      assert has_element?(view, "td", user.email)
      assert has_element?(view, "td", "Marketing email")  # Format function capitalizes and changes _ to space
      
      # Verify View Details button exists
      assert has_element?(view, "button", "View Details")
    end

    test "applies filters", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/admin/consents")

      # Submit filter form with actual user ID instead of empty string
      view
      |> element("form")
      |> render_submit(%{
        "filter" => %{
          "consent_type" => "marketing_email",
          "status" => "active",
          "user_id" => user.id,
          "date_from" => nil,
          "date_to" => nil
        }
      })

      # Verify filter was applied (check for filter values)
      html = render(view)
      assert html =~ "selected=\"selected\">Marketing email"
      assert html =~ "selected=\"selected\">Active"
    end

    test "clears filters", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/admin/consents")

      # Apply a filter first with valid user ID
      view
      |> element("form")
      |> render_submit(%{
        "filter" => %{
          "consent_type" => "marketing_email",
          "status" => "active",
          "user_id" => user.id,
          "date_from" => nil,
          "date_to" => nil
        }
      })

      # Then clear filters
      view
      |> element("button", "Clear Filters")
      |> render_click()

      # Verify filters were cleared
      html = render(view)
      refute html =~ "selected=\"selected\">Marketing email"
      refute html =~ "selected=\"selected\">Active"
    end

    test "shows details modal", %{conn: conn, consent: consent} do
      {:ok, view, _html} = live(conn, ~p"/admin/consents")

      # Click View Details button
      view
      |> element("button[phx-click='show_details'][phx-value-id='#{consent.id}']")
      |> render_click()

      # Verify modal is displayed
      assert has_element?(view, "h3", "Consent Record Details")
      assert has_element?(view, "div.text-sm", "ID")
      assert has_element?(view, "div.text-sm", "User")
      assert has_element?(view, "div.text-sm", "Consent Type")
      assert has_element?(view, "div.text-sm", "Status")
      
      # Check close button works - use more specific selector to avoid ambiguity
      view
      |> element("button.px-3.py-2", "Close")
      |> render_click()
      
      # Modal should be closed now
      refute has_element?(view, "h3", "Consent Record Details")
    end

    test "handles theme toggle", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/consents")

      # Default theme should be light
      html_before = render(view)
      assert html_before =~ "class=\"min-h-screen light\""

      # Trigger theme toggle
      new_html = view |> render_hook("toggle_theme")
      
      # Theme should have changed to dark
      assert new_html =~ "class=\"min-h-screen dark\""
    end

    test "handles page navigation", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/consents")
      
      # Instead of trying to click a pagination button (which might not exist if we don't have enough records),
      # we'll just test the handle_event directly
      view
      |> render_hook("change_page", %{"page" => "1"})
      
      # Verify basic structure still renders
      assert has_element?(view, "th", "ID")
      assert has_element?(view, "th", "User")
    end

    test "redirects anonymous users to login", %{} do
      # Create a non-authenticated connection
      anon_conn = build_conn()

      # Try to access the consents page
      conn = get(anon_conn, ~p"/admin/consents")

      # Should redirect to login page
      assert redirected_to(conn) =~ ~p"/session/new"
    end
  end
end