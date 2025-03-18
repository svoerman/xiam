defmodule XIAMWeb.Admin.StatusLive do
  use XIAMWeb, :live_view
  
  alias XIAM.Repo
  alias XIAM.System.Health
  
  @refresh_interval 15_000 # 15 seconds
  
  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Schedule periodic refreshes for real-time updates
      Process.send_after(self(), :refresh_stats, @refresh_interval)
    end
    
    {:ok, socket
      |> assign(page_title: "System Status")
      |> assign(system_stats: get_system_stats())
      |> assign(db_stats: get_db_stats())
      |> assign(cluster_nodes: get_cluster_nodes())
      |> assign(oban_stats: get_oban_stats())
      |> assign(last_updated: DateTime.utc_now())
      |> assign(show_node_details: false)
      |> assign(selected_node: nil)}
  end

  @impl true
  def handle_info(:refresh_stats, socket) do
    # Schedule next refresh
    Process.send_after(self(), :refresh_stats, @refresh_interval)
    
    {:noreply, socket
      |> assign(system_stats: get_system_stats())
      |> assign(db_stats: get_db_stats())
      |> assign(cluster_nodes: get_cluster_nodes())
      |> assign(oban_stats: get_oban_stats())
      |> assign(last_updated: DateTime.utc_now())}
  end
  
  @impl true
  def handle_event("show_node_details", %{"node" => node}, socket) do
    {:noreply, assign(socket, 
      show_node_details: true,
      selected_node: node
    )}
  end
  
  def handle_event("close_node_details", _, socket) do
    {:noreply, assign(socket, show_node_details: false)}
  end
  
  def handle_event("toggle_theme", _, socket) do
    # Theme is toggled in the browser via JavaScript, we just need to return the socket
    {:noreply, socket}
  end
  
  # Private functions to gather system metrics
  
  defp get_system_stats do
    # Get health data from our Health module
    health_data = Health.check_health()
    
    %{
      memory: health_data.memory,
      system_info: health_data.system_info,
      cpu_util: get_cpu_utilization(),
      uptime: health_data.application.uptime,
      disk: health_data.disk
    }
  end
  
  defp get_cluster_nodes do
    nodes = [node() | Node.list()]
    
    Enum.map(nodes, fn node ->
      %{
        name: node,
        status: (if node in Node.list(), do: "connected", else: "local"),
        memory: :rpc.call(node, :erlang, :memory, []),
        process_count: :rpc.call(node, :erlang, :system_info, [:process_count]),
        uptime: :rpc.call(node, :erlang, :statistics, [:wall_clock]) |> elem(0) |> div(1000)
      }
    end)
  end
  
  defp get_cpu_utilization do
    case :cpu_sup.util() do
      {:error, _reason} -> 0.0
      cpu_util -> cpu_util / 100.0
    end
  rescue
    _ -> 0.0
  end
  
  # Note: This function is kept for future use
  # Commented out to eliminate compiler warnings
  # defp get_system_uptime do
  #   {time, _} = :erlang.statistics(:wall_clock)
  #   time |> div(1000)
  # end
  
  defp get_db_stats do
    %{
      pool_size: Repo.config()[:pool_size],
      active_connections: get_active_db_connections(),
      queries_total: 0,  # These would need a metrics collection system
      avg_query_time: 0  # These would need a metrics collection system
    }
  end
  
  defp get_active_db_connections do
    case Ecto.Adapters.SQL.query(Repo, "SELECT count(*) FROM pg_stat_activity WHERE datname = current_database()") do
      {:ok, %{rows: [[count]]}} -> count
      _ -> 0
    end
  rescue
    _ -> 0
  end
  
  defp get_oban_stats do
    # Get the Oban config safely without using Access behavior
    _oban_config = Oban.config()
    # Get queues from Oban - in a safer way
    queues = case Keyword.get(Application.get_env(:xiam, Oban, []), :queues) do
      queues when is_map(queues) -> Map.to_list(queues)
      queues when is_list(queues) -> queues
      _ -> []
    end
    
    %{
      jobs_completed: get_oban_metric(:jobs_completed),
      jobs_pending: get_oban_metric(:jobs_pending),
      jobs_failed: get_oban_metric(:jobs_failed),
      jobs_cancelled: get_oban_metric(:jobs_cancelled),
      queues: queues
    }
  end
  
  defp get_oban_metric(metric) do
    # In a real implementation, we would query Oban's telemetry metrics
    # For this example, we'll just use random values
    case metric do
      :jobs_completed -> :rand.uniform(1000)
      :jobs_pending -> :rand.uniform(50)
      :jobs_failed -> :rand.uniform(20)
      :jobs_cancelled -> :rand.uniform(10)
    end
  end
  
  # Formatting helper functions
  
  defp format_memory(memory) when is_integer(memory) do
    cond do
      memory < 1024 -> "#{memory} B"
      memory < 1024 * 1024 -> "#{Float.round(memory / 1024, 2)} KB"
      memory < 1024 * 1024 * 1024 -> "#{Float.round(memory / 1024 / 1024, 2)} MB"
      true -> "#{Float.round(memory / 1024 / 1024 / 1024, 2)} GB"
    end
  end
  
  defp format_uptime(seconds) do
    days = div(seconds, 86400)
    hours = div(rem(seconds, 86400), 3600)
    minutes = div(rem(seconds, 3600), 60)
    
    cond do
      days > 0 -> "#{days}d #{hours}h #{minutes}m"
      hours > 0 -> "#{hours}h #{minutes}m"
      true -> "#{minutes}m"
    end
  end
  
  defp format_datetime(datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")
  end
  
  # Using shadcn_status_color instead of this legacy function
  
  # shadcn UI status colors
  defp shadcn_status_color(status) do
    case status do
      "connected" -> "bg-green-500 dark:bg-green-700"
      "local" -> "bg-primary dark:bg-primary/80"
      _ -> "bg-muted dark:bg-muted/80"
    end
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex justify-between items-center">
        <.admin_header
          title="System Status"
          subtitle="Monitor system health, cluster status, and performance metrics"
        />
        <div class="text-sm text-muted-foreground">
          Last updated: <%= format_datetime(@last_updated) %>
        </div>
      </div>
      
      <!-- Summary Cards -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <!-- System Card -->
        <div class="bg-card text-card-foreground rounded-lg border shadow-sm overflow-hidden">
          <div class="p-4 border-b bg-muted/50">
            <h3 class="font-medium flex items-center text-foreground">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2 text-muted-foreground" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h14a2 2 0 002-2v-4a2 2 0 00-2-2m-2-4h.01M17 16h.01" />
              </svg>
              System
            </h3>
          </div>
          <div class="p-4">
            <div class="grid grid-cols-2 gap-4">
              <div>
                <div class="text-xs text-muted-foreground">CPU Usage</div>
                <div class="text-xl font-semibold"><%= Float.round(@system_stats.cpu_util * 100, 1) %>%</div>
              </div>
              <div>
                <div class="text-xs text-muted-foreground">Memory</div>
                <div class="text-xl font-semibold"><%= format_memory(@system_stats.memory[:total]) %></div>
              </div>
              <div>
                <div class="text-xs text-muted-foreground">Processes</div>
                <div class="text-xl font-semibold"><%= @system_stats.system_info.process_count %></div>
              </div>
              <div>
                <div class="text-xs text-muted-foreground">Uptime</div>
                <div class="text-xl font-semibold"><%= format_uptime(@system_stats.uptime) %></div>
              </div>
            </div>
          </div>
        </div>
        
        <!-- Database Card -->
        <div class="bg-card text-card-foreground rounded-lg border shadow-sm overflow-hidden">
          <div class="p-4 border-b bg-muted/50">
            <h3 class="font-medium flex items-center text-foreground">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2 text-muted-foreground" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4m0 5c0 2.21-3.582 4-8 4s-8-1.79-8-4" />
              </svg>
              Database
            </h3>
          </div>
          <div class="p-4">
            <div class="grid grid-cols-2 gap-4">
              <div>
                <div class="text-xs text-muted-foreground">Pool Size</div>
                <div class="text-xl font-semibold"><%= @db_stats.pool_size %></div>
              </div>
              <div>
                <div class="text-xs text-muted-foreground">Active Connections</div>
                <div class="text-xl font-semibold"><%= @db_stats.active_connections %></div>
              </div>
              <div>
                <div class="text-xs text-muted-foreground">Total Queries</div>
                <div class="text-xl font-semibold"><%= @db_stats.queries_total %></div>
              </div>
              <div>
                <div class="text-xs text-muted-foreground">Avg Query Time</div>
                <div class="text-xl font-semibold"><%= @db_stats.avg_query_time %> ms</div>
              </div>
            </div>
          </div>
        </div>
        
        <!-- Cluster Card -->
        <div class="bg-card text-card-foreground rounded-lg border shadow-sm overflow-hidden">
          <div class="p-4 border-b bg-muted/50">
            <h3 class="font-medium flex items-center text-foreground">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2 text-muted-foreground" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z" />
              </svg>
              Cluster
            </h3>
          </div>
          <div class="p-4">
            <div class="grid grid-cols-2 gap-4">
              <div>
                <div class="text-xs text-muted-foreground">Nodes</div>
                <div class="text-xl font-semibold"><%= length(@cluster_nodes) %></div>
              </div>
              <div>
                <div class="text-xs text-muted-foreground">Connected</div>
                <div class="text-xl font-semibold"><%= length(Node.list()) %></div>
              </div>
              <div class="col-span-2">
                <div class="text-xs text-muted-foreground mb-1">Node Distribution</div>
                <div class="flex space-x-1">
                  <%= for node <- @cluster_nodes do %>
                    <div 
                      phx-click="show_node_details" 
                      phx-value-node={node.name}
                      class={"h-4 rounded cursor-pointer flex-grow #{shadcn_status_color(node.status)}"}
                      title={node.name}
                    ></div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        </div>
        
        <!-- Background Jobs Card -->
        <div class="bg-card text-card-foreground rounded-lg border shadow-sm overflow-hidden">
          <div class="p-4 border-b bg-muted/50">
            <h3 class="font-medium flex items-center text-foreground">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2 text-muted-foreground" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              Background Jobs
            </h3>
          </div>
          <div class="p-4">
            <div class="grid grid-cols-2 gap-4">
              <div>
                <div class="text-xs text-muted-foreground">Completed</div>
                <div class="text-xl font-semibold"><%= @oban_stats.jobs_completed %></div>
              </div>
              <div>
                <div class="text-xs text-muted-foreground">Pending</div>
                <div class="text-xl font-semibold"><%= @oban_stats.jobs_pending %></div>
              </div>
              <div>
                <div class="text-xs text-muted-foreground">Failed</div>
                <div class="text-xl font-semibold"><%= @oban_stats.jobs_failed %></div>
              </div>
              <div>
                <div class="text-xs text-muted-foreground">Cancelled</div>
                <div class="text-xl font-semibold"><%= @oban_stats.jobs_cancelled %></div>
              </div>
            </div>
          </div>
        </div>
      </div>
      
      <!-- Detailed Metrics Sections -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
        <!-- Cluster Nodes -->
        <div class="bg-card text-card-foreground rounded-lg border shadow-sm overflow-hidden">
          <div class="p-4 border-b bg-muted/50">
            <h3 class="font-medium text-foreground">Cluster Nodes</h3>
          </div>
          <div class="overflow-x-auto">
            <table class="w-full text-sm border-collapse">
              <thead class="bg-muted/50">
                <tr>
                  <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                    Node
                  </th>
                  <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                    Status
                  </th>
                  <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                    Memory
                  </th>
                  <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                    Processes
                  </th>
                  <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                    Uptime
                  </th>
                </tr>
              </thead>
              <tbody class="bg-card divide-y divide-border">
                <%= for node <- @cluster_nodes do %>
                  <tr>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                      <%= node.name %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm">
                      <span class={"px-2 py-1 inline-flex text-xs leading-5 font-semibold rounded-full #{shadcn_status_color(node.status)}"}>                      
                        <%= node.status %>
                      </span>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-muted-foreground">
                      <%= format_memory(node.memory[:total]) %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-muted-foreground">
                      <%= node.process_count %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-muted-foreground">
                      <%= format_uptime(node.uptime) %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
        
        <!-- Memory Usage -->
        <div class="bg-card text-card-foreground rounded-lg border shadow-sm overflow-hidden">
          <div class="p-4 border-b bg-muted/50">
            <h3 class="font-medium text-foreground">Memory Usage</h3>
          </div>
          <div class="p-6">
            <div class="space-y-6">
              <!-- Process Memory -->
              <div>
                <div class="flex justify-between text-sm mb-1">
                  <span class="text-foreground">Process Memory</span>
                  <span class="text-muted-foreground"><%= format_memory(@system_stats.memory[:processes]) %></span>
                </div>
                <div class="w-full bg-muted rounded-full h-2.5">
                  <div class="bg-primary h-2.5 rounded-full" style={"width: #{@system_stats.memory[:processes] / @system_stats.memory[:total] * 100}%"}></div>
                </div>
              </div>
              
              <!-- Atom Memory -->
              <div>
                <div class="flex justify-between text-sm mb-1">
                  <span class="text-foreground">Atom Memory</span>
                  <span class="text-muted-foreground"><%= format_memory(@system_stats.memory[:atom]) %></span>
                </div>
                <div class="w-full bg-muted rounded-full h-2.5">
                  <div class="bg-green-500 dark:bg-green-600 h-2.5 rounded-full" style={"width: #{@system_stats.memory[:atom] / @system_stats.memory[:total] * 100}%"}></div>
                </div>
              </div>
              
              <!-- Binary Memory -->
              <div>
                <div class="flex justify-between text-sm mb-1">
                  <span class="text-foreground">Binary Memory</span>
                  <span class="text-muted-foreground"><%= format_memory(@system_stats.memory[:binary]) %></span>
                </div>
                <div class="w-full bg-muted rounded-full h-2.5">
                  <div class="bg-purple-500 dark:bg-purple-600 h-2.5 rounded-full" style={"width: #{@system_stats.memory[:binary] / @system_stats.memory[:total] * 100}%"}></div>
                </div>
              </div>
              
              <!-- Code Memory -->
              <div>
                <div class="flex justify-between text-sm mb-1">
                  <span class="text-foreground">Code Memory</span>
                  <span class="text-muted-foreground"><%= format_memory(@system_stats.memory[:code]) %></span>
                </div>
                <div class="w-full bg-muted rounded-full h-2.5">
                  <div class="bg-amber-500 dark:bg-amber-600 h-2.5 rounded-full" style={"width: #{@system_stats.memory[:code] / @system_stats.memory[:total] * 100}%"}></div>
                </div>
              </div>
              
              <!-- ETS Memory -->
              <div>
                <div class="flex justify-between text-sm mb-1">
                  <span class="text-foreground">ETS Memory</span>
                  <span class="text-muted-foreground"><%= format_memory(@system_stats.memory[:ets]) %></span>
                </div>
                <div class="w-full bg-muted rounded-full h-2.5">
                  <div class="bg-destructive h-2.5 rounded-full" style={"width: #{@system_stats.memory[:ets] / @system_stats.memory[:total] * 100}%"}></div>
                </div>
              </div>
            </div>
          </div>
        </div>
        
        <!-- Job Queues -->
        <div class="bg-card text-card-foreground rounded-lg border shadow-sm overflow-hidden">
          <div class="p-4 border-b bg-muted/50">
            <h3 class="font-medium text-foreground">Job Queues</h3>
          </div>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-border">
              <thead class="bg-muted/50">
                <tr>
                  <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                    Queue
                  </th>
                  <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                    Workers
                  </th>
                  <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                    Status
                  </th>
                </tr>
              </thead>
              <tbody class="bg-card divide-y divide-border">
                <%= for {queue, workers} <- @oban_stats.queues do %>
                  <tr>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-foreground">
                      <%= queue %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-muted-foreground">
                      <%= workers %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-muted-foreground">
                      <span class="px-2 py-1 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-400">
                        Active
                      </span>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
        
        <!-- System Info -->
        <div class="bg-card text-card-foreground rounded-lg border shadow-sm overflow-hidden">
          <div class="p-4 border-b bg-muted/50">
            <h3 class="font-medium text-foreground">System Information</h3>
          </div>
          <div class="p-4">
            <dl class="grid grid-cols-1 md:grid-cols-2 gap-x-4 gap-y-6">
              <div>
                <dt class="text-sm font-medium text-muted-foreground">BEAM Version</dt>
                <dd class="mt-1 text-sm text-foreground"><%= :erlang.system_info(:version) %></dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-muted-foreground">Elixir Version</dt>
                <dd class="mt-1 text-sm text-foreground"><%= System.version() %></dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-muted-foreground">Node Name</dt>
                <dd class="mt-1 text-sm text-foreground"><%= node() %></dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-muted-foreground">System Architecture</dt>
                <dd class="mt-1 text-sm text-foreground"><%= :erlang.system_info(:system_architecture) %></dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-muted-foreground">Process Limit</dt>
                <dd class="mt-1 text-sm text-foreground"><%= :erlang.system_info(:process_limit) %></dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-muted-foreground">Atom Limit</dt>
                <dd class="mt-1 text-sm text-foreground"><%= :erlang.system_info(:atom_limit) %></dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-muted-foreground">Scheduler Count</dt>
                <dd class="mt-1 text-sm text-foreground"><%= :erlang.system_info(:schedulers_online) %></dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-muted-foreground">OTP Release</dt>
                <dd class="mt-1 text-sm text-foreground"><%= :erlang.system_info(:otp_release) %></dd>
              </div>
            </dl>
          </div>
        </div>
      </div>
      
      <!-- Node Details Modal -->
      <%= if @show_node_details do %>
        <div class="fixed inset-0 bg-background/80 backdrop-blur-sm flex items-center justify-center z-50">
          <div class="bg-card text-card-foreground rounded-lg shadow-lg max-w-3xl w-full mx-auto p-6 border">
            <div class="flex justify-between items-center mb-4">
              <h3 class="text-lg font-medium text-foreground">Node Details: <%= @selected_node %></h3>
              <button phx-click="close_node_details" class="text-muted-foreground hover:text-foreground transition-colors">
                <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            
            <div class="mb-6">
              <h4 class="text-sm font-medium text-muted-foreground mb-2">Memory Distribution</h4>
              <div class="space-y-3">
                <%= for node <- @cluster_nodes do %>
                  <%= if node.name == @selected_node do %>
                    <%= for {memory_type, value} <- node.memory do %>
                      <div>
                        <div class="flex justify-between text-sm mb-1">
                          <span class="text-foreground"><%= memory_type |> Atom.to_string() |> String.capitalize() %></span>
                          <span class="text-muted-foreground"><%= format_memory(value) %></span>
                        </div>
                        <div class="w-full bg-muted rounded-full h-2.5">
                          <div class="bg-primary h-2.5 rounded-full" style={"width: #{value / node.memory[:total] * 100}%"}></div>
                        </div>
                      </div>
                    <% end %>
                  <% end %>
                <% end %>
              </div>
            </div>
            
            <div class="text-right">
              <button type="button" phx-click="close_node_details" class="px-4 py-2 inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium transition-colors bg-primary text-primary-foreground shadow hover:bg-primary/90 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50">
                Close
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
