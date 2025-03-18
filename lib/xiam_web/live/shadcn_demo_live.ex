defmodule XIAMWeb.ShadcnDemoLive do
  use XIAMWeb, :live_view
  
  # Import shadcn UI components with alias to avoid conflicts
  alias XIAMWeb.Components.UI.Alert
  alias XIAMWeb.Components.UI.Button
  alias XIAMWeb.Components.UI.Card
  alias XIAMWeb.Components.UI.Dropdown
  alias XIAMWeb.Components.UI.Input
  alias XIAMWeb.Components.UI.Label
  alias XIAMWeb.Components.UI.ThemeToggle

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "shadcn UI Demo", email: "", password: "")}
  end

  @impl true
  def handle_event("update_email", %{"value" => email}, socket) do
    {:noreply, assign(socket, email: email)}
  end

  @impl true
  def handle_event("update_password", %{"value" => password}, socket) do
    {:noreply, assign(socket, password: password)}
  end

  @impl true
  def handle_event("submit", _params, socket) do
    # In a real app, you would handle authentication here
    {:noreply, 
     socket
     |> put_flash(:info, "Login attempt with email: #{socket.assigns.email}")
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto py-8">
      <div class="flex justify-between items-center mb-8">
        <h1 class="text-3xl font-bold">shadcn UI Demo</h1>
        <ThemeToggle.theme_toggle />
      </div>
      
      <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
        <!-- Card with Login Form -->
        <Card.card class="max-w-md mx-auto w-full">
          <Card.card_header>
            <Card.card_title>Login</Card.card_title>
            <Card.card_description>Enter your credentials to access your account</Card.card_description>
          </Card.card_header>
          <Card.card_content>
            <form phx-submit="submit" class="space-y-4">
              <div class="space-y-2">
                <Label.label for="email">Email</Label.label>
                <Input.input 
                  id="email" 
                  type="email" 
                  placeholder="name@example.com" 
                  value={@email}
                  phx-change="update_email"
                  required
                />
              </div>
              <div class="space-y-2">
                <Label.label for="password">Password</Label.label>
                <Input.input 
                  id="password" 
                  type="password" 
                  placeholder="••••••••" 
                  value={@password}
                  phx-change="update_password"
                  required
                />
              </div>
              <Button.button type="submit" class="w-full">Sign in</Button.button>
            </form>
          </Card.card_content>
        </Card.card>

        <!-- Component Showcase -->
        <div class="space-y-8">
          <div>
            <h2 class="text-xl font-semibold mb-4">Buttons</h2>
            <div class="flex flex-wrap gap-2">
              <Button.button>Default</Button.button>
              <Button.button variant="secondary">Secondary</Button.button>
              <Button.button variant="destructive">Destructive</Button.button>
              <Button.button variant="outline">Outline</Button.button>
              <Button.button variant="ghost">Ghost</Button.button>
              <Button.button variant="link">Link</Button.button>
            </div>
          </div>

          <div>
            <h2 class="text-xl font-semibold mb-4">Alerts</h2>
            <div class="space-y-4">
              <Alert.alert>
                <Alert.alert_title>Default Alert</Alert.alert_title>
                <Alert.alert_description>This is a default alert.</Alert.alert_description>
              </Alert.alert>
              <Alert.alert variant="destructive">
                <Alert.alert_title>Error Alert</Alert.alert_title>
                <Alert.alert_description>This is a destructive alert.</Alert.alert_description>
              </Alert.alert>
            </div>
          </div>

          <div>
            <h2 class="text-xl font-semibold mb-4">Dropdown</h2>
            <Dropdown.dropdown id="dropdown-demo">
              <:trigger>
                <Button.button variant="outline">Open Menu</Button.button>
              </:trigger>
              <:content>
                <Dropdown.dropdown_item>Profile</Dropdown.dropdown_item>
                <Dropdown.dropdown_item>Settings</Dropdown.dropdown_item>
                <Dropdown.dropdown_separator />
                <Dropdown.dropdown_item>Logout</Dropdown.dropdown_item>
              </:content>
            </Dropdown.dropdown>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
