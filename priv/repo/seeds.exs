# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     XIAM.Repo.insert!(%XIAM.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias XIAM.Repo
alias Xiam.Rbac.Role
alias Xiam.Rbac.Capability
alias XIAM.Users.User
import Ecto.Query

# Check if capabilities already exist to prevent duplicates
# Admin panel capabilities
admin_access = Repo.get_by(Capability, name: "admin_access") ||
  (
    {:ok, cap} = Repo.insert(%Capability{
      name: "admin_access",
      description: "Full access to admin panel"
    })
    cap
  )

admin_users = Repo.get_by(Capability, name: "admin_users") ||
  (
    {:ok, cap} = Repo.insert(%Capability{
      name: "admin_users",
      description: "Manage users from admin panel"
    })
    cap
  )

admin_consents = Repo.get_by(Capability, name: "admin_consents") ||
  (
    {:ok, cap} = Repo.insert(%Capability{
      name: "admin_consents",
      description: "Manage consent records from admin panel"
    })
    cap
  )

# API capabilities
# These are capabilities required for API access
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
  {"view_system_status", "View system status via API"},
  {"anonymize_user", "Anonymize a user via API (GDPR-compliant)"}
]

# Hierarchy access control capabilities
hierarchy_capabilities = [
  {"list_hierarchy_nodes", "List hierarchy nodes via API"},
  {"create_hierarchy_node", "Create hierarchy nodes via API"},
  {"update_hierarchy_node", "Update hierarchy nodes via API"},
  {"delete_hierarchy_node", "Delete hierarchy nodes via API"},
  {"view_hierarchy_node", "View hierarchy node details via API"},
  {"list_hierarchy_access", "List hierarchy access grants via API"},
  {"grant_hierarchy_access", "Grant access to hierarchy nodes via API"},
  {"revoke_hierarchy_access", "Revoke access to hierarchy nodes via API"},
  {"check_hierarchy_access", "Check access to hierarchy nodes via API"}
]

# Insert all API capabilities if missing
created_capabilities = []

# Insert API capabilities
created_capabilities = created_capabilities ++ Enum.map(api_capabilities, fn {name, desc} ->
  Repo.get_by(Capability, name: name) ||
    Repo.insert!(%Capability{name: name, description: desc})
end)

# Insert hierarchy capabilities
created_capabilities = created_capabilities ++ Enum.map(hierarchy_capabilities, fn {name, desc} ->
  Repo.get_by(Capability, name: name) ||
    Repo.insert!(%Capability{name: name, description: desc})
end)

# Check if admin role already exists
admin_role = Repo.get_by(Role, name: "Administrator") ||
  (
    {:ok, role} = Repo.insert(%Role{
      name: "Administrator",
      description: "Full system administrator",
      capabilities: [admin_access, admin_users, admin_consents]
    })
    role
  )

# Ensure admin_role has capabilities
admin_role = admin_role |> Repo.preload(:capabilities)

# Combine all capabilities that need to be added to the admin role
all_required_capabilities = [admin_access, admin_users, admin_consents] ++ created_capabilities

# Find missing capabilities for the admin role
missing_capabilities = all_required_capabilities -- admin_role.capabilities

# If there are missing capabilities, add them to the admin role
if length(missing_capabilities) > 0 do
  # Add the missing capabilities to the role
  IO.puts("Adding #{length(missing_capabilities)} new capabilities to the Administrator role")
  
  # Direct SQL insertion for join table
  Enum.each(missing_capabilities, fn capability ->
    # Execute a direct SQL INSERT to avoid Ecto schema issues with join tables
    Repo.query!("INSERT INTO roles_capabilities (role_id, capability_id) VALUES ($1, $2)", [admin_role.id, capability.id])
  end)

  # Reload role with capabilities
  updated_admin_role = Repo.get!(Role, admin_role.id) |> Repo.preload(:capabilities)
  admin_role = updated_admin_role
end

# Create or update admin user
admin_user = Repo.get_by(User, email: "admin@example.com")

if admin_user do
  # Update existing user with admin role if needed
  if is_nil(admin_user.role_id) do
    updated_admin_user = admin_user
      |> Ecto.Changeset.change(%{role_id: admin_role.id})
      |> Repo.update!()
    admin_user = updated_admin_user
    IO.puts("Updated existing admin user with admin role")
  end
else
  # Create new admin user
  new_admin_user = %User{}
    |> Ecto.Changeset.change(
      email: "admin@example.com",
      password_hash: Pow.Ecto.Schema.Password.pbkdf2_hash("Admin123456!"),
      role_id: admin_role.id
    )
    |> Repo.insert!()
  admin_user = new_admin_user
  IO.puts("Created new admin user")
end

# Reload the admin user with role preloaded
admin_user = Repo.get_by(User, email: "admin@example.com") |> Repo.preload(role: :capabilities)

IO.puts("\nDatabase seeded with initial data:")
IO.puts("Admin user created: admin@example.com | Password: Admin123456!")

if admin_user.role do
  IO.puts("Role assigned: #{admin_user.role.name}")

  capability_names =
    if admin_user.role.capabilities,
      do: Enum.map_join(admin_user.role.capabilities, ", ", & &1.name),
      else: "none"

  IO.puts("Capabilities: #{capability_names}")
else
  IO.puts("ERROR: No role assigned to admin user!")
end

IO.puts("You can now access the admin panel at /admin")
