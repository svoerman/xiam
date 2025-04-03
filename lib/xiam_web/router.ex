defmodule XIAMWeb.Router do
  use XIAMWeb, :router
  use Pow.Phoenix.Router
  use PowAssent.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {XIAMWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :admin_protected do
    plug Pow.Plug.RequireAuthenticated, error_handler: Pow.Phoenix.PlugErrorHandler
    plug XIAMWeb.Plugs.AdminAuthPlug
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :put_secure_browser_headers
    # PlugAttack needs different integration method
  end

  pipeline :skip_csrf_protection do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :put_secure_browser_headers
  end

  scope "/" do
    pipe_through :skip_csrf_protection

    pow_assent_authorization_post_callback_routes()
  end

  scope "/" do
    pipe_through :browser

    pow_routes()
    pow_assent_routes()
  end

  scope "/", XIAMWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/shadcn", ShadcnDemoLive, :index
  end

  # Admin routes
  scope "/admin", XIAMWeb.Admin do
    pipe_through [:browser, :admin_protected]

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
  end

  # API routes with JWT authentication
  pipeline :api_jwt do
    plug :accepts, ["json"]
    plug CORSPlug, origin: ["*"]
    plug XIAMWeb.Plugs.APIAuthPlug
  end

  # Documentation routes
  scope "/", XIAMWeb do
    pipe_through :browser

    # API Documentation UI
    get "/api/docs", SwaggerController, :index
    # Direct access to Swagger JSON
    get "/swagger/api-spec.json", SwaggerController, :api_json
  end

  # Unprotected API routes
  scope "/api", XIAMWeb.API do
    pipe_through :api

    post "/auth/login", AuthController, :login
    get "/health", HealthController, :index
    get "/health/detailed", HealthController, :health
    get "/system/health", SystemController, :health # Keep for backward compatibility
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
    post "/capabilities", AccessControlController, :create_capability
  end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:xiam, :dev_routes) do

    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
