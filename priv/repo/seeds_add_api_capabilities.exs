# Add all API-required capabilities and assign them to the admin role
# Run with: mix run priv/repo/seeds_add_api_capabilities.exs

alias XIAM.Repo
alias Xiam.Rbac.{Role, Capability}
import Ecto.Query

# List of required capabilities as per API code
api_capabilities = [
  {"list_users", "List all users via API"},
  {"view_user", "View a user via API"},
  {"create_user", "Create a user via API"},
  {"update_user", "Update a user via API"},
  {"delete_user", "Delete a user via API"},
  {"list_products", "List products via API"},
  {"create_product", "Create a product via API"},
  {"manage_access", "Manage user access via API"},
  {"manage_capabilities", "Manage capabilities via API"},
  {"view_capabilities", "View product capabilities via API"},
  {"delete_consent", "Delete consent records via API"},
  {"view_system_status", "View system status via API"}
]

# Insert capabilities if missing
inserted_caps = Enum.map(api_capabilities, fn {name, desc} ->
  Repo.get_by(Capability, name: name) ||
    Repo.insert!(%Capability{name: name, description: desc})
end)

# Find the admin role (adjust name if different in your DB)
admin_role = Repo.get_by(Role, name: "Administrator")
|> Repo.preload(:capabilities)

if admin_role do
  # Add any missing capabilities to the admin role
  new_caps = inserted_caps -- admin_role.capabilities
  if new_caps != [] do
    admin_role
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:capabilities, admin_role.capabilities ++ new_caps)
    |> Repo.update!()
    IO.puts("Added new API capabilities to Administrator role.")
  else
    IO.puts("Administrator role already has all API capabilities.")
  end
else
  IO.puts("Administrator role not found! Please create it manually.")
end
