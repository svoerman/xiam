-- Enable ltree extension if not already enabled
CREATE EXTENSION IF NOT EXISTS ltree;

-- Create hierarchy_nodes table
CREATE TABLE IF NOT EXISTS hierarchy_nodes (
  id BIGSERIAL PRIMARY KEY,
  path TEXT NOT NULL,
  node_type TEXT NOT NULL,
  name TEXT NOT NULL,
  metadata JSONB NULL,
  parent_id BIGINT NULL REFERENCES hierarchy_nodes(id) ON DELETE CASCADE,
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for efficient lookups
CREATE INDEX IF NOT EXISTS hierarchy_nodes_parent_id_index ON hierarchy_nodes(parent_id);
CREATE UNIQUE INDEX IF NOT EXISTS hierarchy_nodes_path_index ON hierarchy_nodes(path);
-- Create a GiST index for ltree operations
-- First, verify function exists to cast text to ltree
CREATE OR REPLACE FUNCTION text_to_ltree_safe(p_text text) RETURNS ltree AS $$
BEGIN
    RETURN p_text::ltree;
EXCEPTION WHEN OTHERS THEN
    RETURN ''::ltree;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Now create the index using the function
CREATE INDEX IF NOT EXISTS hierarchy_nodes_path_gist ON hierarchy_nodes USING GIST (text_to_ltree_safe(path) gist_ltree_ops);
-- Install pg_trgm extension if needed
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX IF NOT EXISTS hierarchy_nodes_path_btree ON hierarchy_nodes USING BTREE (path);

-- Create hierarchy_access table
CREATE TABLE IF NOT EXISTS hierarchy_access (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  access_path TEXT NOT NULL,
  role_id BIGINT NOT NULL,
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for the access table
CREATE INDEX IF NOT EXISTS hierarchy_access_user_id_index ON hierarchy_access(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS hierarchy_access_user_id_access_path_index ON hierarchy_access(user_id, access_path);
-- Create a GiST index for ltree path containment/ancestry operations
CREATE INDEX IF NOT EXISTS hierarchy_access_path_gist ON hierarchy_access USING GIST (text_to_ltree_safe(access_path) gist_ltree_ops);
CREATE INDEX IF NOT EXISTS hierarchy_access_path_btree ON hierarchy_access USING BTREE (access_path);

-- Create function for checking user access
CREATE OR REPLACE FUNCTION can_user_access(user_id BIGINT, node_id BIGINT)
RETURNS BOOLEAN LANGUAGE plpgsql AS $$
DECLARE
  target_path ltree;
  has_access boolean;
BEGIN
  SELECT path INTO target_path FROM hierarchy_nodes WHERE id = node_id;
  IF NOT FOUND THEN
    RETURN false;
  END IF;

  -- Cast the target_path text to ltree and check if it's contained within any access_path
  -- Using text_to_ltree() for explicit casting to ensure compatibility
  SELECT EXISTS (
    SELECT 1 FROM hierarchy_access 
    WHERE user_id = can_user_access.user_id 
    AND text_to_ltree(access_path) @> target_path
  ) INTO has_access;

  RETURN has_access;
END;
$$ IMMUTABLE PARALLEL SAFE;
