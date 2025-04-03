defmodule XIAMWeb.DocsLive do
  use XIAMWeb, :live_view
  # Import UI component modules
  # import XIAMWeb.CoreComponents # Removed as unused
  import XIAMWeb.Components.UI
  import XIAMWeb.Components.UI.Card       # Add specific import for Card
  import XIAMWeb.Components.UI.Accordion  # Add specific import for Accordion

  @impl true
  def mount(_params, _session, socket) do
    # Assign an ID for the accordion if needed, or let the component handle it
    {:ok, assign(socket,
      page_title: "XIAM Documentation",
      open_accordion_item: nil # Track open item
    )}
  end

  @impl true
  def handle_event("toggle_accordion", %{"item" => value}, socket) do
    current_open = socket.assigns.open_accordion_item

    new_open =
      if current_open == value do
        nil # Close the currently open item
      else
        value # Open the clicked item
      end

    {:noreply, assign(socket, :open_accordion_item, new_open)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8 bg-background text-foreground space-y-8">
      <%!-- Page Header with Back Link --%>
      <div class="mb-6"> <%# Removed border-b, adjusted mb if needed %>
        <%!-- Back Link styled like admin_header --%>
        <a
          href="#"
          onclick="window.history.back(); return false;"
          class="text-primary hover:text-primary/80 block mb-4"
        >
          ← Back
        </a>
        <h1 class="text-3xl font-bold tracking-tight text-foreground"><%= @page_title %></h1>
        <p class="text-muted-foreground">Installation and Usage Guide</p>
      </div>

      <%!-- Removed separate Back Button div --%>

      <%!-- Introduction Section --%>
      <.card>
        <.card_header>
          <.card_title id="introduction">Introduction</.card_title>
          <.card_description>
            Welcome to XIAM (eXtensible Identity and Access Management).
          </.card_description>
        </.card_header>
        <.card_content class="space-y-4 text-base">
          <p>
            XIAM is a platform built with Elixir and Phoenix, designed to provide robust authentication, authorization, and user management capabilities for modern web applications.
          </p>
          <p>Key features include:</p>
          <ul class="list-disc pl-6 space-y-1">
            <li>User Registration & Login (Email/Password)</li>
            <li>Multi-Factor Authentication (MFA / TOTP)</li>
            <li>Role-Based Access Control (RBAC) with Roles and Capabilities</li>
            <li>Admin Panel for managing Users, Roles, and Capabilities</li>
            <li>JWT-based API Authentication</li>
            <li>Background Job Processing (via Oban)</li>
          </ul>
        </.card_content>
      </.card>

      <%!-- Installation Section --%>
      <.card>
        <.card_header>
          <.card_title id="installation">Installation</.card_title>
          <.card_description>
            Follow these steps to get a local development instance of XIAM running.
          </.card_description>
        </.card_header>
        <.card_content>
          <.accordion type="single" collapsible class="w-full">

            <%!-- Prerequisites Item --%>
            <% item_1_value = "item-1" %>
            <% item_1_state = if @open_accordion_item == item_1_value, do: "open", else: "closed" %>
            <.accordion_item value={item_1_value}>
              <.accordion_trigger value={item_1_value} state={item_1_state} class="text-lg font-medium">Prerequisites</.accordion_trigger>
              <%= if item_1_state == "open" do %>
                <.accordion_content state={item_1_state} class="text-base">
                  <ul class="list-disc pl-6 space-y-1 pt-2">
                    <li>Elixir (~> 1.15)</li>
                    <li>Erlang/OTP (~> 26)</li>
                    <li>PostgreSQL (12+)</li>
                    <li>Node.js (for asset building)</li>
                  </ul>
                </.accordion_content>
              <% end %>
            </.accordion_item>

            <%!-- Setup Steps Item --%>
            <% item_2_value = "item-2" %>
            <% item_2_state = if @open_accordion_item == item_2_value, do: "open", else: "closed" %>
            <.accordion_item value={item_2_value}>
              <.accordion_trigger value={item_2_value} state={item_2_state} class="text-lg font-medium">Setup Steps</.accordion_trigger>
              <%= if item_2_state == "open" do %>
                <.accordion_content state={item_2_state} class="text-base space-y-4 pt-2">
                  <ol class="list-decimal pl-6 space-y-6">
                    <li>
                      <strong>Clone the repository:</strong>
                      <pre class="mt-2 bg-muted p-4 rounded-md font-mono text-sm overflow-x-auto"><code class="language-bash">
                        git clone https://your-repo-url/xiam.git
                        cd xiam
                      </code></pre>
                    </li>
                    <li>
                      <strong>Install dependencies:</strong>
                      <pre class="mt-2 bg-muted p-4 rounded-md font-mono text-sm overflow-x-auto"><code class="language-bash">
                        mix deps.get
                        cd assets && npm install && cd ..
                      </code></pre>
                    </li>
                    <li>
                      <strong>Configure your environment:</strong> Copy <code>.env.example</code> to <code>.env</code> (if provided) or set the necessary environment variables directly. Key variables include:
                      <ul class="list-disc pl-6 space-y-1 mt-2">
                        <li><code>DATABASE_URL</code>: Connection string for your PostgreSQL database (e.g., <code>ecto://user:pass@localhost/xiam_dev</code>)</li>
                        <li><code>SECRET_KEY_BASE</code>: Generate using <code>mix phx.gen.secret</code>.</li>
                        <li><code>JWT_SIGNING_SECRET</code>: A secure secret for signing API tokens (generate one).</li>
                        <li>(Optional) OAuth provider keys (<code>GITHUB_CLIENT_ID</code>, <code>GOOGLE_CLIENT_ID</code>, etc.) if using social login.</li>
                      </ul>
                      <p class="mt-2">Ensure these variables are loaded into your shell environment or managed via a tool like Doppler or direnv.</p>
                    </li>
                    <li>
                      <strong>Create and migrate the database:</strong>
                      <pre class="mt-2 bg-muted p-4 rounded-md font-mono text-sm overflow-x-auto"><code class="language-bash">
                        mix ecto.create
                        mix ecto.migrate
                      </code></pre>
                    </li>
                    <li>
                      <strong>(Optional) Seed the database:</strong> To create an initial admin user and roles:
                      <pre class="mt-2 bg-muted p-4 rounded-md font-mono text-sm overflow-x-auto"><code class="language-bash">
                        mix run priv/repo/seeds.exs
                      </code></pre>
                      <p class="mt-2">Check the seed script output for default admin credentials.</p>
                    </li>
                    <li>
                      <strong>Start the Phoenix server:</strong>
                      <pre class="mt-2 bg-muted p-4 rounded-md font-mono text-sm overflow-x-auto"><code class="language-bash">
                        mix phx.server
                      </code></pre>
                    </li>
                  </ol>
                  <p class="pt-4">XIAM should now be running at <a href="http://localhost:4000" class="text-primary underline hover:no-underline">http://localhost:4000</a>.</p>
                </.accordion_content>
              <% end %>
            </.accordion_item>

          </.accordion>
        </.card_content>
      </.card>

      <%!-- Usage Section --%>
      <.card>
        <.card_header>
          <.card_title id="usage">Usage</.card_title>
          <.card_description>Understanding and using XIAM features.</.card_description>
        </.card_header>
        <.card_content class="space-y-6 text-base">
          <div>
            <h3 class="text-lg font-semibold mb-2" id="core-concepts">Core Concepts</h3>
            <ul class="list-disc pl-6 space-y-1">
              <li><strong>Users:</strong> Individuals who can log in to the system.</li>
              <li><strong>Roles:</strong> Collections of permissions assigned to users (e.g., "Administrator", "Editor").</li>
              <li><strong>Capabilities:</strong> Specific permissions or actions that can be performed (e.g., "manage_users", "edit_content"). Roles are composed of multiple capabilities.</li>
              <li><strong>Products:</strong> (If applicable) A way to group capabilities, often relating to different parts of an application or different services.</li>
            </ul>
          </div>

          <div>
            <h3 class="text-lg font-semibold mb-2" id="web-interface">Web Interface</h3>
            <ul class="list-disc pl-6 space-y-1">
              <li><strong>Registration/Login:</strong> Users can register via the "Register" link or log in via the "Login" link on the homepage.</li>
              <li><strong>Admin Panel:</strong> Accessible at <code>/admin</code> (for users with the appropriate role/capability). This panel allows management of:
                <ul class="list-circle pl-6 space-y-1 mt-1">
                  <li>Users (Assigning roles, enabling/disabling MFA)</li>
                  <li>Roles & Capabilities (Creating, editing, deleting roles and capabilities, assigning capabilities to roles)</li>
                  <li>Products (If applicable, managing products and their associated capabilities)</li>
                  <li>Entity Access (Fine-grained permissions for specific resources, if implemented)</li>
                </ul>
              </li>
            </ul>
          </div>

          <div>
            <h3 class="text-lg font-semibold mb-2" id="api">API</h3>
            <p>
              XIAM provides a RESTful API for programmatic interaction. Authentication is handled via JWT (JSON Web Tokens). Obtain a token via the <code>/api/auth/login</code> endpoint using user credentials. Include the token in the <code>Authorization: Bearer &lt;token&gt;</code> header for subsequent requests.
            </p>
            <p class="mt-2">
              API documentation is available via Swagger UI at <a href="/api/docs" class="text-primary underline hover:no-underline">/api/docs</a>.
            </p>
          </div>

          <div>
            <h3 class="text-lg font-semibold mb-2" id="configuration">Configuration</h3>
            <p>
              Most runtime configuration, especially for production, is handled via environment variables loaded in <code>config/runtime.exs</code>. Key settings include database connection, secret keys, and external service integrations (like mailers or OAuth providers).
            </p>
            <p class="mt-2">
              Default application configuration and Pow settings can be found in <code>config/config.exs</code>. Security-related settings like password complexity and account lockout are configured in <code>config/runtime.exs</code> for the production environment.
            </p>
          </div>
        </.card_content>
      </.card>

      <%!-- Development Section --%>
      <.card>
        <.card_header>
          <.card_title id="development">Development</.card_title>
        </.card_header>
        <.card_content class="space-y-4 text-base">
          <div>
            <h3 class="text-lg font-semibold mb-2" id="running-tests">Running Tests</h3>
            <p>Execute the test suite using:</p>
            <pre class="mt-2 bg-muted p-4 rounded-md font-mono text-sm overflow-x-auto"><code class="language-bash">
              mix test
            </code></pre>
          </div>
        </.card_content>
      </.card>

    </div>
    """
  end

  # Removed the local admin_header function as it conflicts with the imported one.
end
