# Seeds for the hierarchical access control system
#
# Run this file after the main seeds.exs to populate the hierarchy:
#
#     mix run priv/repo/hierarchy_seeds.exs
#
# This will create a sample hierarchy with various node types and access grants

alias XIAM.Repo
alias XIAM.Hierarchy
alias XIAM.Hierarchy.{Node, Access}
alias XIAM.Users.User
alias Xiam.Rbac.Role
import Ecto.Query

# Get or create test users
# First, get admin user
admin_user = Repo.get_by(User, email: "admin@example.com")
IO.puts("Found admin user: #{admin_user.email}")

# Create or get user1
user1 = Repo.get_by(User, email: "user1@example.com") ||
  (
    IO.puts("Creating user1...")
    {:ok, user} = Pow.Ecto.Context.create(
      %{email: "user1@example.com", password: "Password123!", password_confirmation: "Password123!"},
      otp_app: :xiam
    )
    user
  )

# Create or get user2
user2 = Repo.get_by(User, email: "user2@example.com") ||
  (
    IO.puts("Creating user2...")
    {:ok, user} = Pow.Ecto.Context.create(
      %{email: "user2@example.com", password: "Password123!", password_confirmation: "Password123!"},
      otp_app: :xiam
    )
    user
  )
IO.puts("Using users: \n- #{admin_user.email}\n- #{user1.email}\n- #{user2.email}")

# Get or create roles
roles = 
  case Repo.all(from r in Role, limit: 3) do
    [] -> 
      # If no roles exist, the main seeds.exs should be run first
      raise "Please run the main seeds.exs first to create roles"
    roles -> roles
  end

[admin_role | _] = roles
IO.puts("Using admin role: #{admin_role.name}")

# Create example hierarchy
IO.puts("\nCreating example hierarchy...")

# Create geographic hierarchy (organization by region)
{:ok, region_root} = Hierarchy.create_node(%{name: "Regions", node_type: "region", parent_id: nil})
IO.puts("Created root node: Regions (#{region_root.id})")

# Create Europe branch
{:ok, europe} = Hierarchy.create_node(%{name: "Europe", node_type: "region", parent_id: region_root.id})
{:ok, france} = Hierarchy.create_node(%{name: "France", node_type: "region", parent_id: europe.id})
{:ok, germany} = Hierarchy.create_node(%{name: "Germany", node_type: "region", parent_id: europe.id})
{:ok, uk} = Hierarchy.create_node(%{name: "United Kingdom", node_type: "region", parent_id: europe.id})

# Create North America branch
{:ok, north_america} = Hierarchy.create_node(%{name: "North America", node_type: "region", parent_id: region_root.id})
{:ok, usa} = Hierarchy.create_node(%{name: "USA", node_type: "region", parent_id: north_america.id})
{:ok, canada} = Hierarchy.create_node(%{name: "Canada", node_type: "region", parent_id: north_america.id})

# Create Asia branch 
{:ok, asia} = Hierarchy.create_node(%{name: "Asia", node_type: "region", parent_id: region_root.id})
{:ok, japan} = Hierarchy.create_node(%{name: "Japan", node_type: "region", parent_id: asia.id})
{:ok, china} = Hierarchy.create_node(%{name: "China", node_type: "region", parent_id: asia.id})

IO.puts("Created geographic hierarchy with 10 nodes")

# Create department hierarchy (organization by function)
{:ok, dept_root} = Hierarchy.create_node(%{name: "Departments", node_type: "department", parent_id: nil})
IO.puts("Created root node: Departments (#{dept_root.id})")

{:ok, engineering} = Hierarchy.create_node(%{name: "Engineering", node_type: "department", parent_id: dept_root.id})
{:ok, frontend} = Hierarchy.create_node(%{name: "Frontend", node_type: "department", parent_id: engineering.id})
{:ok, backend} = Hierarchy.create_node(%{name: "Backend", node_type: "department", parent_id: engineering.id})
{:ok, devops} = Hierarchy.create_node(%{name: "DevOps", node_type: "department", parent_id: engineering.id})

{:ok, marketing} = Hierarchy.create_node(%{name: "Marketing", node_type: "department", parent_id: dept_root.id})
{:ok, social} = Hierarchy.create_node(%{name: "Social Media", node_type: "department", parent_id: marketing.id})
{:ok, content} = Hierarchy.create_node(%{name: "Content", node_type: "department", parent_id: marketing.id})

{:ok, sales} = Hierarchy.create_node(%{name: "Sales", node_type: "department", parent_id: dept_root.id})
{:ok, enterprise} = Hierarchy.create_node(%{name: "Enterprise", node_type: "department", parent_id: sales.id})
{:ok, smb} = Hierarchy.create_node(%{name: "SMB", node_type: "department", parent_id: sales.id})

IO.puts("Created department hierarchy with 10 nodes")

# Grant access to users
IO.puts("\nGranting access rights...")

# Admin user gets access to everything
{:ok, _} = Hierarchy.grant_access(admin_user.id, region_root.id, admin_role.id)
{:ok, _} = Hierarchy.grant_access(admin_user.id, dept_root.id, admin_role.id)
IO.puts("- Granted admin access to all hierarchies")

# user1 gets access to Europe regions
{:ok, _} = Hierarchy.grant_access(user1.id, europe.id, admin_role.id)
IO.puts("- Granted user1 access to Europe region")

# user2 gets access to Engineering department
{:ok, _} = Hierarchy.grant_access(user2.id, engineering.id, admin_role.id)
IO.puts("- Granted user2 access to Engineering department")

# Test access
IO.puts("\nTesting access inherited through hierarchy...")
has_access = Hierarchy.can_access?(user1.id, france.id)
IO.puts("- user1 access to France: #{has_access}")

has_access = Hierarchy.can_access?(user1.id, usa.id)
IO.puts("- user1 access to USA: #{has_access}")

has_access = Hierarchy.can_access?(user2.id, frontend.id)
IO.puts("- user2 access to Frontend: #{has_access}")

has_access = Hierarchy.can_access?(user2.id, marketing.id)
IO.puts("- user2 access to Marketing: #{has_access}")

has_access = Hierarchy.can_access?(admin_user.id, japan.id)
IO.puts("- admin access to Japan: #{has_access}")

IO.puts("\nHierarchy seeding completed successfully!")
