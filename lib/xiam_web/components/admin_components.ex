defmodule XIAMWeb.AdminComponents do
  @moduledoc """
  Provides UI components for the admin interface.
  """
  use Phoenix.Component

  @doc """
  Renders a standard admin page header with back button and title.

  ## Examples

      <.admin_header title="User Management" subtitle="Manage user accounts and permissions" />
  """
  attr :title, :string, required: true, doc: "the title of the page"
  attr :subtitle, :string, default: nil, doc: "the optional subtitle of the page"
  attr :show_back_link, :boolean, default: true, doc: "whether to show the back to dashboard link"

  def admin_header(assigns) do
    ~H"""
    <div class="mb-8">
      <%= if @show_back_link do %>
        <a href="/admin" class="text-primary hover:text-primary/80 block mb-4">
          ← Back to Dashboard
        </a>
      <% end %>
      <h1 class="text-3xl font-bold text-foreground" data-test-id="page-title"><%= @title %></h1>
      <%= if @subtitle do %>
        <div class="text-sm text-muted-foreground">
          <%= @subtitle %>
        </div>
      <% end %>
    </div>
    """
  end
end
