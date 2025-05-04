defmodule XIAM.Repo.Migrations.AddCanUserAccessFunction do
  use Ecto.Migration

  def up do
    # First, drop the existing function if it exists
    execute """
    DROP FUNCTION IF EXISTS can_user_access(bigint, bigint);
    """
    
    # Then create the new function
    execute """
    CREATE OR REPLACE FUNCTION can_user_access(p_user_id bigint, p_node_id bigint)
    RETURNS boolean
    LANGUAGE plpgsql
    AS $$
    DECLARE
      node_path ltree;
      has_access boolean;
    BEGIN
      -- Get the path of the node
      SELECT path INTO node_path FROM hierarchy_nodes WHERE id = p_node_id;
      
      IF node_path IS NULL THEN
        RETURN false;
      END IF;
      
      -- Check if the user has access to this node or any of its ancestors
      -- node_path <@ access_path means the node_path is contained within access_path
      -- but we want to check if access_path is an ancestor of node_path or equal to it
      -- so we should use @> (contains) operator in the other direction
      SELECT EXISTS (
        SELECT 1 FROM hierarchy_access 
        WHERE user_id = p_user_id 
        AND access_path::ltree @> node_path
      ) INTO has_access;
      
      RETURN has_access;
    END;
    $$;
    """
  end

  def down do
    execute """
    DROP FUNCTION IF EXISTS can_user_access(bigint, bigint);
    """
  end
end
