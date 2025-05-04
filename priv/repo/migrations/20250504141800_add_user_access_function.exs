defmodule XIAM.Repo.Migrations.AddUserAccessFunction do
  use Ecto.Migration

  def up do
    execute """
    CREATE FUNCTION can_user_access(user_id bigint, node_id bigint)
    RETURNS boolean LANGUAGE plpgsql AS $$
    DECLARE
      target_path ltree;
      has_access boolean;
    BEGIN
      SELECT path INTO target_path FROM hierarchy_nodes WHERE id = node_id;
      IF NOT FOUND THEN
        RETURN false;
      END IF;

      -- Check if any user access path contains the target path
      -- This uses ltree's containment operator @>
      -- Using the text2ltree function for safe conversion
      SELECT EXISTS (
        SELECT 1 FROM hierarchy_access 
        WHERE user_id = can_user_access.user_id 
        AND text2ltree(access_path) @> target_path
      ) INTO has_access;

      RETURN has_access;
    END;
    $$ IMMUTABLE PARALLEL SAFE;
    """
  end

  def down do
    execute "DROP FUNCTION IF EXISTS can_user_access(bigint, bigint)"
  end
end
