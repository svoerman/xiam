defmodule XIAM.Hierarchy.PathCalculator do
  @moduledoc """
  Provides functions for calculating and manipulating hierarchy paths.
  Uses PostgreSQL's ltree path format for hierarchy management.
  """

  @doc """
  Builds a child path by appending a sanitized name to the parent path.
  """
  def build_child_path(parent_path, name) do
    sanitized = sanitize_name(name)
    if parent_path == "" do
      sanitized
    else
      "#{parent_path}.#{sanitized}"
    end
  end

  @doc """
  Sanitizes a name for use in a path.
  Replaces spaces with underscores and removes non-alphanumeric characters.
  """
  def sanitize_name(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_]+/, "_")
    |> String.replace(~r/^_+|_+$/, "")
    |> ensure_valid_path_label()
  end
  def sanitize_name(_), do: "unnamed"

  @doc """
  Ensures that a path label is valid (not empty and not starting with a number).
  """
  def ensure_valid_path_label(""), do: "unnamed"
  def ensure_valid_path_label(<<first::utf8, _rest::binary>> = label) when first >= ?0 and first <= ?9 do
    "n#{label}"
  end
  def ensure_valid_path_label(label), do: label

  @doc """
  Gets the parent path from a given path by removing the last label.
  Returns nil if the path has no parent (is a root).
  """
  def parent_path(path) when is_binary(path) do
    case String.split(path, ".") do
      [_] -> nil
      parts -> parts |> Enum.slice(0..-2//-1) |> Enum.join(".")
    end
  end

  @doc """
  Gets the last label from a path (the node's own name part).
  """
  def path_label(path) when is_binary(path) do
    case String.split(path, ".") do
      [] -> nil
      parts -> List.last(parts)
    end
  end

  @doc """
  Checks if one path is an ancestor of another.
  """
  def is_ancestor?(ancestor_path, descendant_path) when is_binary(ancestor_path) and is_binary(descendant_path) do
    String.starts_with?(descendant_path, "#{ancestor_path}.")
  end
  
  @doc """
  Checks if a path is a descendant of another path.
  This is equivalent to checking if the second path is an ancestor of the first.
  """
  def is_descendant?(path, ancestor_id) when is_binary(path) do
    # When used with a node ID, extract the path from the ID
    # Note: This is a compatibility function for the BatchOperations module
    cond do
      is_binary(ancestor_id) -> String.starts_with?(path, "#{ancestor_id}.")
      true -> false
    end
  end

  @doc """
  Checks if one path is a direct parent of another.
  """
  def is_parent?(parent_path, child_path) when is_binary(parent_path) and is_binary(child_path) do
    parent_parts = String.split(parent_path, ".")
    child_parts = String.split(child_path, ".")
    
    parent_length = length(parent_parts)
    child_length = length(child_parts)
    
    child_length == parent_length + 1 && 
    Enum.take(child_parts, parent_length) == parent_parts
  end

  @doc """
  Gets the depth of a path (how many levels deep in the hierarchy).
  Root nodes have depth 1.
  """
  def path_depth(path) when is_binary(path) do
    String.split(path, ".") |> length()
  end

  @doc """
  Calculates the common ancestor path between two paths.
  Returns nil if they don't share a common ancestor.
  """
  def common_ancestor(path1, path2) when is_binary(path1) and is_binary(path2) do
    parts1 = String.split(path1, ".")
    parts2 = String.split(path2, ".")
    
    {common, _} = Enum.reduce_while(Enum.zip(parts1, parts2), {[], true}, fn {p1, p2}, {acc, _} ->
      if p1 == p2 do
        {:cont, {acc ++ [p1], true}}
      else
        {:halt, {acc, false}}
      end
    end)
    
    case common do
      [] -> nil
      parts -> Enum.join(parts, ".")
    end
  end

  @doc """
  Returns the path as a list of labels.
  """
  def path_to_list(path) when is_binary(path) do
    String.split(path, ".")
  end

  @doc """
  Creates a path from a list of labels.
  """
  def list_to_path(labels) when is_list(labels) do
    Enum.join(labels, ".")
  end
end
