#!/usr/bin/env elixir

# Add the current directory to the code path and run the script
# This script cleans up orphaned hierarchy_access records that reference non-existent nodes
#
# To run this script:
# mix run scripts/cleanup_orphaned_access.exs

alias XIAM.Repo
require Logger

Logger.info("Starting cleanup of orphaned hierarchy_access records...")

# Step 1: Get all unique access_paths from hierarchy_access
{:ok, access_paths_result} = Repo.query("""
  SELECT DISTINCT access_path FROM hierarchy_access
""")

access_paths = access_paths_result.rows |> Enum.map(fn [path] -> path end)
Logger.info("Found #{length(access_paths)} unique access paths to check")

# Step 2: Identify which access_paths don't have corresponding nodes
orphaned_paths = Enum.filter(access_paths, fn path ->
  # We need to check if any node's path matches this access path
  # For each access path, query if a matching node exists
  {:ok, check_result} = Repo.query("""
    SELECT EXISTS (
      SELECT 1 FROM hierarchy_nodes
      WHERE path::text = $1::text
    )
  """, [path])

  # Extract the result (true/false if node exists)
  [[exists]] = check_result.rows

  # If exists is false, this is an orphaned path
  !exists
end)

Logger.info("Found #{length(orphaned_paths)} orphaned access paths")

# Step 3: Delete the orphaned access records
if length(orphaned_paths) > 0 do
  # We'll do this in batches to avoid excessively large queries
  orphaned_paths
  |> Enum.chunk_every(100)
  |> Enum.with_index(1)
  |> Enum.each(fn {batch, batch_num} ->
    placeholders = Enum.with_index(batch, 1) |> Enum.map(fn {_, i} -> "$#{i}" end) |> Enum.join(", ")

    {:ok, delete_result} = Repo.query("""
      DELETE FROM hierarchy_access
      WHERE access_path IN (#{placeholders})
      RETURNING id, user_id, access_path
    """, batch)

    Logger.info("Batch #{batch_num}: Deleted #{length(delete_result.rows)} access records")
  end)

  Logger.info("Cleanup complete. All orphaned access records have been removed.")
else
  Logger.info("No orphaned access records found. No cleanup needed.")
end

# Step 4: Output a summary of what was cleaned up
Logger.info("Cleanup summary:")
Logger.info("- Total unique access paths checked: #{length(access_paths)}")
Logger.info("- Orphaned access paths removed: #{length(orphaned_paths)}")
Logger.info("- The hierarchy_access table is now consistent with hierarchy_nodes")
