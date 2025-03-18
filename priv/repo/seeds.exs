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
alias XIAM.RBAC.Role
alias XIAM.RBAC.Capability
alias XIAM.Users.User
import Ecto.Query

# Check if capabilities already exist to prevent duplicates
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

if Enum.empty?(admin_role.capabilities) do
  # Add capabilities to role if they're missing
  Repo.delete_all(from rc in "roles_capabilities", where: rc.role_id == ^admin_role.id)

  Enum.each([admin_access, admin_users, admin_consents], fn capability ->
    Repo.insert!(%{role_id: admin_role.id, capability_id: capability.id}, prefix: "roles_capabilities")
  end)
  
  # Reload role with capabilities
  admin_role = Repo.get!(Role, admin_role.id) |> Repo.preload(:capabilities)
end

# Create or update admin user
admin_user = Repo.get_by(User, email: "admin@example.com")

if admin_user do
  # Update existing user with admin role
  admin_user = 
    admin_user
    |> Ecto.Changeset.change(role_id: admin_role.id)
    |> Repo.update!()
  
  IO.puts("\nUpdated existing admin user with proper role")
else
  # Create new admin user
  admin_user =
    %User{}
    |> Ecto.Changeset.change(
      email: "admin@example.com",
      password_hash: Pow.Ecto.Schema.Password.pbkdf2_hash("Admin123456!"),
      role_id: admin_role.id
    )
    |> Repo.insert!()
end

# Verify user has the right role
admin_user = Repo.get!(User, admin_user.id) |> Repo.preload(role: :capabilities)

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
