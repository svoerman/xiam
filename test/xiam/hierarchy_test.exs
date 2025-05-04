defmodule XIAM.HierarchyTest do
  use XIAM.DataCase

  alias XIAM.Hierarchy
  alias XIAM.Hierarchy.Node
  alias XIAM.Repo

  describe "nodes" do
    @valid_attrs %{
      name: "Test Node",
      node_type: "company",
      metadata: %{"key" => "value"}
    }
    @update_attrs %{
      name: "Updated Node",
      node_type: "department",
      metadata: %{"key" => "updated value"}
    }
    @invalid_attrs %{name: nil, node_type: nil}

    def node_fixture(attrs \\ %{}) do
      attrs = Enum.into(attrs, @valid_attrs)
      {:ok, node} = Hierarchy.create_node(attrs)
      node
    end

    test "list_nodes/0 returns all nodes" do
      node = node_fixture()
      assert Hierarchy.list_nodes() |> Enum.map(& &1.id) |> Enum.member?(node.id)
    end

    test "get_node/1 returns the node with given id" do
      node = node_fixture()
      assert Hierarchy.get_node(node.id).id == node.id
    end

    test "create_node/1 with valid data creates a node" do
      assert {:ok, %Node{} = node} = Hierarchy.create_node(@valid_attrs)
      assert node.name == "Test Node"
      assert node.node_type == "company"
      assert node.metadata == %{"key" => "value"}
      assert node.path == "test_node"
    end

    test "create_node/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Hierarchy.create_node(@invalid_attrs)
    end

    test "create_node/1 creates a child node with proper path" do
      parent = node_fixture()
      attrs = Map.put(@valid_attrs, :parent_id, parent.id)
      assert {:ok, %Node{} = child} = Hierarchy.create_node(attrs)
      assert child.parent_id == parent.id
      assert child.path == "#{parent.path}.test_node"
    end

    test "update_node/2 with valid data updates the node" do
      node = node_fixture()
      assert {:ok, %Node{} = node} = Hierarchy.update_node(node, @update_attrs)
      assert node.name == "Updated Node"
      assert node.node_type == "department"
      assert node.metadata == %{"key" => "updated value"}
    end

    test "update_node/2 with invalid data returns error changeset" do
      node = node_fixture()
      assert {:error, %Ecto.Changeset{}} = Hierarchy.update_node(node, @invalid_attrs)
    end

    test "delete_node/1 deletes the node and its descendants" do
      parent = node_fixture()
      child_attrs = Map.put(@valid_attrs, :parent_id, parent.id)
      {:ok, child} = Hierarchy.create_node(child_attrs)
      
      assert {:ok, _} = Hierarchy.delete_node(parent)
      assert nil == Hierarchy.get_node(parent.id)
      assert nil == Hierarchy.get_node(child.id)
    end

    test "is_descendant?/2 correctly identifies descendant relationships" do
      parent = node_fixture()
      
      child_attrs = Map.put(@valid_attrs, :parent_id, parent.id)
      {:ok, child} = Hierarchy.create_node(child_attrs)
      
      grandchild_attrs = Map.put(@valid_attrs, :parent_id, child.id)
      grandchild_attrs = Map.put(grandchild_attrs, :name, "Grandchild")
      {:ok, grandchild} = Hierarchy.create_node(grandchild_attrs)
      
      assert Hierarchy.is_descendant?(child.id, parent.id)
      assert Hierarchy.is_descendant?(grandchild.id, parent.id)
      assert Hierarchy.is_descendant?(grandchild.id, child.id)
      refute Hierarchy.is_descendant?(parent.id, child.id)
      refute Hierarchy.is_descendant?(child.id, grandchild.id)
    end

    test "move_subtree/2 moves a node and its descendants to a new parent" do
      old_parent = node_fixture(name: "Old Parent")
      new_parent = node_fixture(name: "New Parent")
      
      # Create a node under old_parent
      node_attrs = Map.put(@valid_attrs, :parent_id, old_parent.id)
      {:ok, node} = Hierarchy.create_node(node_attrs)
      
      # Create a child under node
      child_attrs = Map.put(@valid_attrs, :parent_id, node.id)
      child_attrs = Map.put(child_attrs, :name, "Child")
      {:ok, child} = Hierarchy.create_node(child_attrs)
      
      # Move the node to new_parent
      assert {:ok, _moved_node} = Hierarchy.move_subtree(node, new_parent.id)
      
      # Get refreshed records
      refreshed_node = Hierarchy.get_node(node.id)
      refreshed_child = Hierarchy.get_node(child.id)
      
      # Check relationships
      assert refreshed_node.parent_id == new_parent.id
      assert String.starts_with?(refreshed_node.path, "#{new_parent.path}.")
      
      # Check that child was also moved
      assert String.starts_with?(refreshed_child.path, refreshed_node.path)
    end

    test "move_subtree/2 prevents moving a node to its own descendant" do
      parent = node_fixture()
      
      child_attrs = Map.put(@valid_attrs, :parent_id, parent.id)
      {:ok, child} = Hierarchy.create_node(child_attrs)
      
      # Try to move parent to child (would create cycle)
      assert {:error, :would_create_cycle} = Hierarchy.move_subtree(parent, child.id)
    end
  end

  describe "access" do
    setup do
      # Import TestHelpers
      import XIAM.TestHelpers
      
      # Create a hierarchy
      {:ok, country} = Hierarchy.create_node(%{name: "USA", node_type: "country"})
      {:ok, company} = Hierarchy.create_node(%{name: "Acme", node_type: "company", parent_id: country.id})
      {:ok, department} = Hierarchy.create_node(%{name: "HR", node_type: "department", parent_id: company.id})
      {:ok, team} = Hierarchy.create_node(%{name: "Recruiting", node_type: "team", parent_id: department.id})
      
      # Create a test user using our helper that works with the WebAuthn flow
      {:ok, user} = create_test_user(%{
        email: "test@example.com"
      })
      
      # Create a test role with a unique name
      random_suffix = :rand.uniform(1000000)
      {:ok, role} = %Xiam.Rbac.Role{}
        |> Xiam.Rbac.Role.changeset(%{name: "Viewer_#{random_suffix}", description: "Test role"})
        |> Repo.insert()
      
      %{country: country, company: company, department: department, team: team, user: user, role: role}
    end
    
    test "grant_access/3 grants access to a node", %{user: user, department: department, role: role} do
      assert {:ok, access} = Hierarchy.grant_access(user.id, department.id, role.id)
      assert access.user_id == user.id
      assert access.access_path == department.path
      assert access.role_id == role.id
    end
    
    test "can_access?/2 correctly checks access inheritance", %{user: user, country: country, company: company, department: department, team: team, role: role} do
      # Grant access at department level
      {:ok, _} = Hierarchy.grant_access(user.id, department.id, role.id)
      
      # User should have access to department and its descendants (team)
      assert Hierarchy.can_access?(user.id, department.id)
      assert Hierarchy.can_access?(user.id, team.id)
      
      # But not to ancestors (country, company) - access doesn't flow upward
      refute Hierarchy.can_access?(user.id, country.id)
      refute Hierarchy.can_access?(user.id, company.id)
    end
    
    test "revoke_access/2 removes access", %{user: user, department: department, team: team, role: role} do
      # Grant access
      {:ok, _} = Hierarchy.grant_access(user.id, department.id, role.id)
      
      # Verify access was granted
      assert Hierarchy.can_access?(user.id, department.id)
      assert Hierarchy.can_access?(user.id, team.id)
      
      # Revoke access
      {:ok, _} = Hierarchy.revoke_access(user.id, department.id)
      
      # Verify access was revoked
      refute Hierarchy.can_access?(user.id, department.id)
      refute Hierarchy.can_access?(user.id, team.id)
    end
    
    test "list_accessible_nodes/1 returns all nodes a user can access", %{user: user, department: department, team: team, role: role} do
      # Grant access at department level
      {:ok, _} = Hierarchy.grant_access(user.id, department.id, role.id)
      
      # Get accessible nodes
      accessible_nodes = Hierarchy.list_accessible_nodes(user.id)
      accessible_ids = Enum.map(accessible_nodes, & &1.id)
      
      # Should include department and team
      assert Enum.member?(accessible_ids, department.id)
      assert Enum.member?(accessible_ids, team.id)
      
      # Should not include nodes the user doesn't have access to
      refute length(accessible_nodes) > 2
    end
  end
end
