defmodule XIAMWeb.Router do
  use XIAMWeb, :router
  use Pow.Phoenix.Router
  use PowAssent.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug Pow.Plug.Session
    plug :fetch_live_flash
    plug :put_root_layout, html: {XIAMWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug XIAMWeb.Plugs.CSPHeaderPlug
  end

  pipeline :admin_protected do
    plug Pow.Plug.RequireAuthenticated, error_handler: Pow.Phoenix.PlugErrorHandler
    plug XIAMWeb.Plugs.AdminAuthPlug
  end

  pipeline :protected do
    plug Pow.Plug.RequireAuthenticated, error_handler: Pow.Phoenix.PlugErrorHandler
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :put_secure_browser_headers
    # PlugAttack needs different integration method
  end

  pipeline :skip_csrf_protection do
    # CSRF protection is skipped ONLY for PowAssent OAuth callback POSTs, which cannot include CSRF tokens.
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :put_secure_browser_headers
    plug XIAMWeb.Plugs.CSPHeaderPlug
  end

  # API routes with JWT authentication
  pipeline :api_jwt do
    plug :accepts, ["json"]
    plug CORSPlug, origin: ["*"]
    plug XIAMWeb.Plugs.APIAuthPlug
  end

  pipeline :api_session do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug Pow.Plug.RequireAuthenticated, error_handler: Pow.Phoenix.PlugErrorHandler
  end

  # Special pipeline for passkey operations that need session but bypass CSRF
  # This is required because WebAuthn browser APIs make custom fetch requests
  # that don't easily support adding CSRF tokens
  pipeline :passkey_api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug Pow.Plug.RequireAuthenticated, error_handler: Pow.Phoenix.PlugErrorHandler
  end

  # Pow authentication routes
  scope "/" do
    pipe_through :skip_csrf_protection
    pow_assent_authorization_post_callback_routes()
  end

  scope "/" do
    pipe_through :browser
    pow_routes()
    pow_assent_routes()
  end

  # Main routes
  scope "/", XIAMWeb do
    pipe_through :browser

    # Home page
    get "/", PageController, :home

    # Authentication routes
    get "/auth/passkey/complete", AuthController, :complete_passkey_auth

    # LiveView routes
    live "/shadcn", ShadcnDemoLive, :index
    live "/docs", DocsLive, :index
  end

  # Serve OpenAPI Specification and Swagger UI
  scope "/api/docs", XIAMWeb do
    pipe_through [:api]

    # Serve static OpenAPI JSON
    get "/openapi.json", SwaggerController, :api_json
    
    # Serve Swagger UI from our own template
    get "/", SwaggerController, :index
  end

  # User account routes
  scope "/account", XIAMWeb do
    pipe_through [:browser, :protected]
    
    # Use LiveAuth hooks for user authentication
    live_session :account,
      on_mount: {XIAMWeb.LiveAuth, :require_authenticated},
      session: {XIAMWeb.LiveAuth, :build_admin_session, []} do
      live "/", AccountSettingsLive, :index
    end
  end

  # Admin routes
  scope "/admin", XIAMWeb.Admin do
    pipe_through [:browser, :admin_protected]
    
    # Use LiveAuth hooks for admin authentication
    live_session :admin,
      on_mount: {XIAMWeb.LiveAuth, :require_admin},
      session: {XIAMWeb.LiveAuth, :build_admin_session, []} do
      live "/", DashboardLive, :index
      live "/users", UsersLive, :index
      live "/users/:id", UsersLive, :show
      live "/roles", RolesLive, :index
      live "/roles/:id", RolesLive, :show
      live "/entity-access", EntityAccessLive, :index
      live "/products", ProductsLive, :index
      live "/gdpr", GDPRLive, :index
      live "/settings", SettingsLive, :index
      live "/audit-logs", AuditLogsLive, :index
      live "/status", StatusLive, :index
      live "/consents", ConsentRecordsLive, :index
      live "/hierarchy", HierarchyLive, :index
    end
  end

  # Unprotected API routes
  scope "/api", XIAMWeb.API do
    pipe_through :api

    post "/auth/login", AuthController, :login
    get "/health", HealthController, :index
    get "/health/detailed", HealthController, :health
    get "/system/health", SystemController, :health # Keep for backward compatibility
    
    # Passkey authentication routes (unprotected)
    get "/auth/passkey/options", PasskeyController, :authentication_options
    post "/auth/passkey", PasskeyController, :authenticate
  end

  # MFA API routes - require partial token
  scope "/api", XIAMWeb.API do
    pipe_through [:api, :api_jwt]
    
    get "/auth/mfa/challenge", AuthController, :mfa_challenge
    post "/auth/mfa/verify", AuthController, :mfa_verify
  end

  # Passkey API using session cookies
  scope "/api", XIAMWeb.API do
    pipe_through [:passkey_api]
    get "/passkeys/registration_options", PasskeyController, :registration_options
    post "/passkeys/register", PasskeyController, :register
    get "/passkeys", PasskeyController, :list_passkeys
    get "/passkeys/debug", PasskeyController, :debug_passkeys  # Debug endpoint
    delete "/passkeys/:id", PasskeyController, :delete_passkey
  end

  # Protected API routes requiring JWT authentication
  scope "/api", XIAMWeb.API do
    pipe_through [:api, :api_jwt]

    # Auth routes
    post "/auth/refresh", AuthController, :refresh_token
    get "/auth/verify", AuthController, :verify_token
    post "/auth/logout", AuthController, :logout

    # System routes
    get "/system/status", SystemController, :status

    # User management routes with capability checks
    get "/users", UsersController, :index
    get "/users/:id", UsersController, :show
    post "/users", UsersController, :create
    put "/users/:id", UsersController, :update
    delete "/users/:id", UsersController, :delete
    post "/users/:id/anonymize", UsersController, :anonymize

    # Consent management routes
    get "/consents", ConsentsController, :index
    post "/consents", ConsentsController, :create
    put "/consents/:id", ConsentsController, :update
    delete "/consents/:id", ConsentsController, :delete

    # Access Control Routes
    post "/access", AccessControlController, :set_user_access
    get "/access", AccessControlController, :get_user_access
    resources "/products", ProductController, only: [:index, :create]
    get "/products/:product_id/capabilities", AccessControlController, :get_product_capabilities
    
    # Hierarchy Routes
    get "/hierarchy/nodes", HierarchyController, :list_nodes
    get "/hierarchy/nodes/roots", HierarchyController, :list_root_nodes
    post "/hierarchy/nodes", HierarchyController, :create_node
    get "/hierarchy/nodes/:id", HierarchyController, :get_node
    put "/hierarchy/nodes/:id", HierarchyController, :update_node
    delete "/hierarchy/nodes/:id", HierarchyController, :delete_node
    get "/hierarchy/nodes/:id/children", HierarchyController, :get_node_children
    get "/hierarchy/nodes/:id/descendants", HierarchyController, :get_node_descendants
    
    # Hierarchy Access Routes
    get "/hierarchy/access", HierarchyController, :list_access_grants
    post "/hierarchy/access", HierarchyController, :create_access_grant
    delete "/hierarchy/access/:id", HierarchyController, :delete_access_grant
    get "/hierarchy/access/node/:node_id", HierarchyController, :list_node_access_grants
    get "/hierarchy/access/user/:user_id", HierarchyController, :list_user_access_grants
    post "/hierarchy/check-access", HierarchyController, :check_user_access
    post "/hierarchy/check-access-by-path", HierarchyController, :check_user_access_by_path
    get "/hierarchy/users/:user_id/accessible-nodes", HierarchyController, :list_user_accessible_nodes

    # Hierarchy Access Control Routes
    scope "/v1" do
      # Basic hierarchy node management
      get "/hierarchy", HierarchyController, :index
      get "/hierarchy/:id", HierarchyController, :show
      post "/hierarchy", HierarchyController, :create
      put "/hierarchy/:id", HierarchyController, :update
      delete "/hierarchy/:id", HierarchyController, :delete
      
      # Hierarchy relationships
      get "/hierarchy/:id/descendants", HierarchyController, :descendants
      get "/hierarchy/:id/ancestry", HierarchyController, :ancestry
      post "/hierarchy/:id/move", HierarchyController, :move
      
      # Batch operations
      post "/hierarchy/batch/move", HierarchyController, :batch_move
      post "/hierarchy/batch/delete", HierarchyController, :batch_delete
      
      # Access management
      get "/hierarchy/access/check/:id", HierarchyController, :check_access
      post "/hierarchy/access/batch/check", HierarchyController, :batch_check_access
      post "/hierarchy/access/grant", HierarchyController, :grant_access
      post "/hierarchy/access/batch/grant", HierarchyController, :batch_grant_access
      delete "/hierarchy/access/revoke", HierarchyController, :revoke_access
      post "/hierarchy/access/batch/revoke", HierarchyController, :batch_revoke_access
    end
    post "/capabilities", AccessControlController, :create_capability
    
    # Hierarchy Access Routes
    get "/hierarchy/access/:node_id", HierarchyAccessController, :check_access
  end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:xiam, :dev_routes) do
    scope "/dev" do
      pipe_through :browser
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
