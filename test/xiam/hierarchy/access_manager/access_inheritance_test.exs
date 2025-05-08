defmodule XIAM.Hierarchy.AccessManager.AccessInheritanceTest do
  @moduledoc """
  Tests focused on verifying access inheritance behaviors in the hierarchy.
  
  These tests ensure that access granted at a higher level in the hierarchy
  correctly propagates to child nodes according to the system's access rules.
  """
  
  use XIAM.ResilientTestCase
  
  # Import only the hierarchy test helpers
  import XIAM.HierarchyTestHelpers
  
  alias XIAM.Hierarchy.AccessManager
  
  setup do
    # First ensure the repo is started with explicit applications
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    {:ok, _} = Application.ensure_all_started(:postgrex)
    
    # Get a fresh database connection
    Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
    
    # Ensure repository is properly started
    XIAM.ResilientDatabaseSetup.ensure_repository_started()
    
    # Ensure ETS tables exist for Phoenix-related operations
    XIAM.ETSTestHelper.ensure_ets_tables_exist()
    XIAM.ETSTestHelper.initialize_endpoint_config()
    
    # Create a multi-level test hierarchy directly
    fixtures = create_multi_level_test_hierarchy()
    
    # Return the fixtures for the test context
    fixtures
  end
  
  # Helper function to create a multi-level test hierarchy with unique identifiers
  defp create_multi_level_test_hierarchy do
    # Generate unique timestamps for all entities
    timestamp = System.system_time(:millisecond)
    random_suffix = :rand.uniform(100_000)
    
    # Create test user directly - get the user struct directly
    user_email = "test_#{timestamp}_#{random_suffix}@example.com"
    user = create_test_user(%{email: user_email})
    
    # Create test role directly - get the role struct directly
    role_name = "Viewer_#{timestamp}_#{random_suffix}"
    role = create_test_role(role_name)
    
    # Create country node directly using Node struct
    country = %XIAM.Hierarchy.Node{
      name: "Country_#{timestamp}_#{random_suffix}", 
      node_type: "country",
      path: "country_#{timestamp}_#{random_suffix}"
    } |> XIAM.Repo.insert!()
    
    # Create company node as child of country
    company = %XIAM.Hierarchy.Node{
      name: "Company_#{timestamp}_#{random_suffix}",
      node_type: "company",
      parent_id: country.id,
      path: "#{country.path}.company_#{timestamp}_#{random_suffix}"
    } |> XIAM.Repo.insert!()
    
    # Create department node as child of company
    department = %XIAM.Hierarchy.Node{
      name: "Department_#{timestamp}_#{random_suffix}",
      node_type: "department",
      parent_id: company.id,
      path: "#{company.path}.department_#{timestamp}_#{random_suffix}"
    } |> XIAM.Repo.insert!()
    
    # Create team node as child of department
    team = %XIAM.Hierarchy.Node{
      name: "Team_#{timestamp}_#{random_suffix}",
      node_type: "team",
      parent_id: department.id,
      path: "#{department.path}.team_#{timestamp}_#{random_suffix}"
    } |> XIAM.Repo.insert!()
    
    # Return all test entities without wrapping in {:ok, ...}
    %{country: country, company: company, department: department, team: team, user: user, role: role}
  end
  
  describe "access inheritance" do
    test "can_access?/2 correctly checks access inheritance", 
         %{user: user, country: country, company: company, department: department, team: team, role: role} do
      
      # Extract IDs for clarity
      user_id = user.id
      country_id = country.id
      company_id = company.id
      department_id = department.id
      team_id = team.id
      role_id = role.id
      
      # Test cases are wrapped with bootstrap protection for resilience
      XIAM.BootstrapHelper.with_bootstrap_protection(fn ->
        # 1. Verify no access initially
        {:ok, has_initial_access} = XIAM.BootstrapHelper.safely_bootstrap(fn ->
          XIAM.Hierarchy.can_access?(user_id, department_id)
        end)
        refute has_initial_access, "User should not have access before it is granted"
        
        # 2. Grant access at company level
        {:ok, _} = XIAM.BootstrapHelper.safely_bootstrap(fn ->
          AccessManager.grant_access(user_id, company_id, role_id)
        end)
        
        # 3. Verify access to company
        {:ok, has_company_access} = XIAM.BootstrapHelper.safely_bootstrap(fn ->
          XIAM.Hierarchy.can_access?(user_id, company_id)
        end)
        assert has_company_access, "User should have direct access to company"
        
        # 4. Verify access propagates to department (child of company)
        {:ok, has_department_access} = XIAM.BootstrapHelper.safely_bootstrap(fn ->
          XIAM.Hierarchy.can_access?(user_id, department_id)
        end)
        assert has_department_access, "User should have inherited access to department"
        
        # 5. Verify access propagates to team (grandchild of company)
        {:ok, has_team_access} = XIAM.BootstrapHelper.safely_bootstrap(fn ->
          XIAM.Hierarchy.can_access?(user_id, team_id)
        end)
        assert has_team_access, "User should have inherited access to team"
        
        # 6. Verify access does NOT propagate upward to country (parent of company)
        {:ok, has_country_access} = XIAM.BootstrapHelper.safely_bootstrap(fn ->
          XIAM.Hierarchy.can_access?(user_id, country_id)
        end)
        refute has_country_access, "User should not have access to parent nodes"
      end)
    end
    
    test "revoke_access/2 removes access but preserves inheritance",
         %{user: user, company: company, department: department, team: team, role: role} do
      
      # Extract IDs for clarity
      user_id = user.id
      company_id = company.id
      department_id = department.id
      team_id = team.id
      role_id = role.id
      
      # Test cases are wrapped with bootstrap protection for resilience
      XIAM.BootstrapHelper.with_bootstrap_protection(fn ->
        # 1. Grant access at both company and department level
        {:ok, _} = XIAM.BootstrapHelper.safely_bootstrap(fn ->
          AccessManager.grant_access(user_id, company_id, role_id)
        end)
        
        {:ok, _} = XIAM.BootstrapHelper.safely_bootstrap(fn ->
          AccessManager.grant_access(user_id, department_id, role_id)
        end)
        
        # 2. Verify access to all levels
        {:ok, has_company_access} = XIAM.BootstrapHelper.safely_bootstrap(fn ->
          XIAM.Hierarchy.can_access?(user_id, company_id)
        end)
        assert has_company_access, "User should have direct access to company"
        
        {:ok, has_department_access} = XIAM.BootstrapHelper.safely_bootstrap(fn ->
          XIAM.Hierarchy.can_access?(user_id, department_id)
        end)
        assert has_department_access, "User should have direct access to department"
        
        {:ok, has_team_access} = XIAM.BootstrapHelper.safely_bootstrap(fn ->
          XIAM.Hierarchy.can_access?(user_id, team_id)
        end)
        assert has_team_access, "User should have inherited access to team"
        
        # 3. Revoke access at department level
        {:ok, _} = XIAM.BootstrapHelper.safely_bootstrap(fn ->
          XIAM.Hierarchy.revoke_access(user_id, department_id)
        end)
        
        # 4. Verify department access is revoked, but inherited access from company still works
        {:ok, has_department_access_after_revoke} = XIAM.BootstrapHelper.safely_bootstrap(fn ->
          XIAM.Hierarchy.can_access?(user_id, department_id)
        end)
        assert has_department_access_after_revoke, 
          "User should still have inherited access to department from company"
        
        # 5. Revoke access at company level
        {:ok, _} = XIAM.BootstrapHelper.safely_bootstrap(fn ->
          XIAM.Hierarchy.revoke_access(user_id, company_id)
        end)
        
        # 6. Verify all access is now revoked
        {:ok, has_company_access_after_revoke} = XIAM.BootstrapHelper.safely_bootstrap(fn ->
          XIAM.Hierarchy.can_access?(user_id, company_id)
        end)
        refute has_company_access_after_revoke, "User should no longer have access to company"
        
        {:ok, has_department_access_after_all_revoked} = XIAM.BootstrapHelper.safely_bootstrap(fn ->
          XIAM.Hierarchy.can_access?(user_id, department_id)
        end)
        refute has_department_access_after_all_revoked, "User should no longer have access to department"
        
        {:ok, has_team_access_after_all_revoked} = XIAM.BootstrapHelper.safely_bootstrap(fn ->
          XIAM.Hierarchy.can_access?(user_id, team_id)
        end)
        refute has_team_access_after_all_revoked, "User should no longer have access to team"
      end)
    end
  end
end
