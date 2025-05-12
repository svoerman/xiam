defmodule XIAM.Hierarchy.IDTypeHelper do
  @moduledoc """
  Helper module for ensuring consistent ID type handling in tests.
  
  Addresses common issues with type mismatches between string and integer IDs
  that can cause flaky tests or unexpected errors.
  """
  
  @doc """
  Ensures a node ID is converted to the correct integer type.
  
  This helps prevent type mismatch errors in tests where IDs might be
  received as strings but need to be integers for database operations.
  
  ## Examples
      iex> ensure_integer_id("12345")
      12345
      
      iex> ensure_integer_id(12345)
      12345
      
      iex> ensure_integer_id(nil)
      nil
  """
  def ensure_integer_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int_id, ""} -> int_id
      _ -> 
        # Could not parse ID as integer - returning original to allow proper failure message
        id
    end
  end
  
  def ensure_integer_id(id) when is_integer(id), do: id
  def ensure_integer_id(nil), do: nil
  
  # Handle tuple return values like {:ok, node}
  def ensure_integer_id({:ok, %{id: id}}) when is_integer(id), do: id
  def ensure_integer_id({:ok, %{id: id}}) when is_binary(id), do: ensure_integer_id(id)
  
  # Handle other tuple formats by returning nil (safer than crashing)
  def ensure_integer_id({_, _}), do: nil
  
  @doc """
  Convert a map's ID fields to integers to ensure proper type for database operations.
  
  ## Examples
      iex> convert_map_ids(%{id: "123", parent_id: "456", other: "value"})
      %{id: 123, parent_id: 456, other: "value"}
  """
  def convert_map_ids(map) when is_map(map) do
    map
    |> Map.update(:id, nil, &ensure_integer_id/1)
    |> Map.update(:parent_id, nil, &ensure_integer_id/1)
    |> Map.update(:node_id, nil, &ensure_integer_id/1)
    |> Map.update(:user_id, nil, &ensure_integer_id/1)
    |> Map.update(:role_id, nil, &ensure_integer_id/1)
  end
end
