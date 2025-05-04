defmodule XIAMWeb.Admin.DashboardLive do
  use XIAMWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Admin Dashboard")}
  end

  @impl true
  def handle_event("toggle_theme", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""

    <div class="container mx-auto px-4 py-8">
      <div class="admin-header">
        <.admin_header
          title="XIAM Admin Dashboard"
          subtitle="Manage your CIAM system including users, roles, and permissions"
          show_back_link={false}
        />
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <!-- Users Management Card -->
        <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-6">
          <h2 class="text-xl font-semibold mb-4 text-foreground">User Management</h2>
          <p class="text-muted-foreground mb-4">Manage user accounts, roles, and multi-factor authentication settings.</p>
          <.link patch={~p"/admin/users"} class="text-primary hover:text-primary/80 font-medium transition-colors">
            Manage Users →
          </.link>
        </div>

        <!-- Roles & Capabilities Card -->
        <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-6">
          <h2 class="text-xl font-semibold mb-4 text-foreground">Roles & Capabilities</h2>
          <p class="text-muted-foreground mb-4">Configure roles and permissions to control access to your application.</p>
          <.link patch={~p"/admin/roles"} class="text-primary hover:text-primary/80 font-medium transition-colors">
            Manage Roles →
          </.link>
        </div>

        <!-- Entity Access Card -->
        <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-6">
          <h2 class="text-xl font-semibold mb-4 text-foreground">Entity Access</h2>
          <p class="text-muted-foreground mb-4">Manage fine-grained access control for specific entities and resources.</p>
          <.link patch={~p"/admin/entity-access"} class="text-primary hover:text-primary/80 font-medium transition-colors">
            Manage Entity Access →
          </.link>
        </div>

        <!-- Hierarchy Management Card -->
        <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-6">
          <h2 class="text-xl font-semibold mb-4 text-foreground">Hierarchy Management</h2>
          <p class="text-muted-foreground mb-4">Manage hierarchical access control for large-scale organizational structures.</p>
          <.link patch={~p"/admin/hierarchy"} class="text-primary hover:text-primary/80 font-medium transition-colors">
            Manage Hierarchy →
          </.link>
        </div>

        <!-- Products & Capabilities Card -->
        <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-6">
          <h2 class="text-xl font-semibold mb-4 text-foreground">Products & Capabilities</h2>
          <p class="text-muted-foreground mb-4">Define products and their associated capabilities for access control.</p>
          <.link patch={~p"/admin/products"} class="text-primary hover:text-primary/80 font-medium transition-colors">
            Manage Products →
          </.link>
        </div>

        <!-- GDPR Compliance Card -->
        <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-6">
          <h2 class="text-xl font-semibold mb-4 text-foreground">GDPR Compliance</h2>
          <p class="text-muted-foreground mb-4">Manage user consent, data portability, and the right to be forgotten.</p>
          <.link patch={~p"/admin/gdpr"} class="text-primary hover:text-primary/80 font-medium transition-colors">
            Manage GDPR →
          </.link>
        </div>

        <!-- System Settings Card -->
        <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-6">
          <h2 class="text-xl font-semibold mb-4 text-foreground">System Settings</h2>
          <p class="text-muted-foreground mb-4">Configure system-wide settings and preferences.</p>
          <.link patch={~p"/admin/settings"} class="text-primary hover:text-primary/80 font-medium transition-colors">
            Manage Settings →
          </.link>
        </div>

        <!-- Audit Logs Card -->
        <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-6">
          <h2 class="text-xl font-semibold mb-4 text-foreground">Audit Logs</h2>
          <p class="text-muted-foreground mb-4">Review audit logs of user activities and system events.</p>
          <.link patch={~p"/admin/audit-logs"} class="text-primary hover:text-primary/80 font-medium transition-colors">
            View Logs →
          </.link>
        </div>

        <!-- Status Card -->
        <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-6">
          <h2 class="text-xl font-semibold mb-4 text-foreground">System Status</h2>
          <p class="text-muted-foreground mb-4">Monitor system health, node status, and background job processing.</p>
          <.link patch={~p"/admin/status"} class="text-primary hover:text-primary/80 font-medium transition-colors">
            View Status →
          </.link>
        </div>

        <!-- Consent Records Card -->
        <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-6">
          <h2 class="text-xl font-semibold mb-4 text-foreground">Consent Records</h2>
          <p class="text-muted-foreground mb-4">Manage and track user consent records for GDPR compliance.</p>
          <.link patch={~p"/admin/consents"} class="text-primary hover:text-primary/80 font-medium transition-colors">
            Manage Consents →
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
