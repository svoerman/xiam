defmodule XIAM.TestHelpers do
  @moduledoc """
  Helper functions for testing XIAM functionality.
  """
  
  import Plug.Conn
  # Removed unused alias: alias XIAM.Users
  alias Xiam.Rbac
  alias XIAM.Repo
  
  @doc """
  Creates a test user with a random email, compatible with the usernameless WebAuthn flow.
  """
  def create_test_user(attrs \\ %{}) do
    email = "test_#{:rand.uniform(1000000)}@example.com"
    
    # In the usernameless WebAuthn flow, we may need different parameters
    # Based on the available functions, we'll use create_user_passkey/4
    
    # First, create a minimal user record using a direct Repo insert
    # This bypasses the WebAuthn flow for testing purposes
    {:ok, user} = %XIAM.Users.User{}
      |> Ecto.Changeset.change(
        email: email,
        password_hash: Pow.Ecto.Schema.Password.pbkdf2_hash("Password123!"),
        role_id: attrs[:role_id]
      )
      |> XIAM.Repo.insert()
    
    {:ok, user}
  end
  
  @doc """
  Creates a test role with the given name.
  """
  def create_test_role(name, attrs \\ %{}) do
    attrs = Map.merge(%{
      name: name,
      description: "Test role for #{name}"
    }, attrs)
    
    Rbac.Role.changeset(%Rbac.Role{}, attrs)
    |> Repo.insert()
  end
  
  @doc """
  Sets up authentication headers for a user.
  """
  def auth_user(conn, user, opts \\ []) do
    # Generate a token for the user
    token_config = Application.get_env(:xiam, :jwt_config, [])
    _secret_key = Keyword.get(token_config, :secret_key, "test_secret") # Prefix with underscore since unused
    expiry = Keyword.get(opts, :exp, 3600) # Default 1 hour expiry
    
    current_time = System.system_time(:second)
    
    claims = %{
      "sub" => user.id,
      "email" => user.email,
      "role_id" => user.role_id,
      "iat" => current_time,
      "exp" => current_time + expiry,
      "type" => "access"
    }
    
    # Normally we'd use JOSE or a similar library for proper JWT generation
    # but for testing purposes we can just encode a simple token
    token = Base.encode64(Jason.encode!(%{
      alg: "HS256",
      typ: "JWT",
      claims: claims
    }))
    
    put_req_header(conn, "authorization", "Bearer #{token}")
  end
  
  @doc """
  Adds a capability to a role.
  """
  def add_capability_to_role(role, capability_name) do
    capability = Repo.get_by(Rbac.Capability, name: capability_name) ||
      Repo.insert!(%Rbac.Capability{name: capability_name, description: "Test capability"})
    
    # Associate capability with role
    Repo.query!(
      "INSERT INTO roles_capabilities (role_id, capability_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
      [role.id, capability.id]
    )
    
    # Return the updated role with capabilities
    Repo.get(Rbac.Role, role.id) |> Repo.preload(:capabilities)
  end
  
  @doc """
  Adds all hierarchy-related capabilities to a role.
  """
  def add_hierarchy_capabilities_to_role(role) do
    hierarchy_capabilities = [
      "list_hierarchy_nodes",
      "create_hierarchy_node",
      "update_hierarchy_node",
      "delete_hierarchy_node",
      "view_hierarchy_node",
      "list_hierarchy_access",
      "grant_hierarchy_access",
      "revoke_hierarchy_access",
      "check_hierarchy_access"
    ]
    
    Enum.reduce(hierarchy_capabilities, role, fn capability_name, updated_role ->
      add_capability_to_role(updated_role, capability_name)
    end)
  end
end
