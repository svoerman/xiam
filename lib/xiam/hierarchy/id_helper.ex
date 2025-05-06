defmodule XIAM.Hierarchy.IDHelper do
  @moduledoc """
  Helper functions to handle ID type conversions and normalization.
  
  This module provides utility functions to normalize IDs between string and integer formats,
  resolving common type mismatch issues in tests and across API boundaries.
  """
  
  @doc """
  Ensures a role ID is in the correct format expected by the Hierarchy system.
  
  ## Examples
  
      iex> normalize_role_id("role_123")
      123
      
      iex> normalize_role_id(456)
      456
      
      iex> normalize_role_id(%{id: 789})
      789
  """
  def normalize_role_id(role_id) when is_binary(role_id) do
    cond do
      # Handle test role IDs in format "role_123"
      String.match?(role_id, ~r/^role_\d+$/) ->
        [_, num] = Regex.run(~r/^role_(\d+)$/, role_id)
        String.to_integer(num)
      
      # Handle normal string integers
      true ->
        case Integer.parse(role_id) do
          {id, _} -> id
          :error -> role_id
        end
    end
  end
  
  def normalize_role_id(role_id) when is_integer(role_id), do: role_id
  
  # Handle the case where a role struct is passed instead of just the ID
  def normalize_role_id(%{id: id}), do: normalize_role_id(id)
  
  # Fallback for other cases
  def normalize_role_id(other), do: other
  
  @doc """
  Ensures a user ID is in the correct format expected by the Hierarchy system.
  
  The Hierarchy access system expects user IDs to be integers, but they may be 
  passed as strings from API endpoints or certain test contexts.
  
  ## Examples
  
      iex> normalize_user_id("123")
      123
      
      iex> normalize_user_id(456)
      456
      
      iex> normalize_user_id(%{id: 789})
      789
  """
  def normalize_user_id(user_id) when is_binary(user_id) do
    cond do
      # Handle test user IDs in format "user_123"
      String.match?(user_id, ~r/^user_\d+$/) ->
        [_, num] = Regex.run(~r/^user_(\d+)$/, user_id)
        String.to_integer(num)
      
      # Handle normal string integers
      true ->
        case Integer.parse(user_id) do
          {id, _} -> id
          :error -> user_id  # If it can't be parsed as an integer, return as is
        end
    end
  end
  
  def normalize_user_id(user_id) when is_integer(user_id), do: user_id
  
  # Handle the case where a user struct is passed instead of just the ID
  def normalize_user_id(%{id: id}), do: normalize_user_id(id)
  
  # Fallback for other cases
  def normalize_user_id(other), do: other
  
  @doc """
  Ensures a node ID is in the correct format expected by the Hierarchy system.
  
  ## Examples
  
      iex> normalize_node_id("123")
      123
      
      iex> normalize_node_id(456)
      456
      
      iex> normalize_node_id(%{id: 789})
      789
  """
  def normalize_node_id(node_id) when is_binary(node_id) do
    cond do
      # Handle test node IDs in format "node_123"
      String.match?(node_id, ~r/^node_\d+$/) ->
        [_, num] = Regex.run(~r/^node_(\d+)$/, node_id)
        String.to_integer(num)
      
      # Handle normal string integers
      true ->
        case Integer.parse(node_id) do
          {id, _} -> id
          :error -> node_id
        end
    end
  end
  
  def normalize_node_id(node_id) when is_integer(node_id), do: node_id
  
  # Handle the case where a node struct is passed instead of just the ID
  def normalize_node_id(%{id: id}), do: normalize_node_id(id)
  
  # Fallback for other cases
  def normalize_node_id(other), do: other
end
