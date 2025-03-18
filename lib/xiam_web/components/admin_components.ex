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

  def admin_header(assigns) do
    ~H"""
    <div class="mb-8">
      <a href="/admin" class="text-primary hover:text-primary/80 block mb-4">
        ← Back to Dashboard
      </a>
      <h1 class="text-3xl font-bold text-foreground"><%= @title %></h1>
      <%= if @subtitle do %>
        <div class="text-sm text-muted-foreground">
          <%= @subtitle %>
        </div>
      <% end %>
    </div>
    """
  end
end
