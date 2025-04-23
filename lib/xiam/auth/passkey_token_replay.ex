defmodule XIAM.Auth.PasskeyTokenReplay do
  @moduledoc """
  Simple in-memory replay protection for passkey token handoff.
  Stores used tokens (user_id:timestamp) in an ETS table with TTL.
  This is NOT persistent and is reset on application restart.
  """
  use GenServer

  @table :passkey_token_replay
  @ttl_seconds 300  # 5 minutes, configurable

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def mark_used(user_id, timestamp) do
    :ets.insert(@table, {{user_id, timestamp}, expire_at()})
    :ok
  end

  def used?(user_id, timestamp) do
    case :ets.lookup(@table, {user_id, timestamp}) do
      [{{^user_id, ^timestamp}, expires}] ->
        if expires > now() do
          true
        else
          # Expired, cleanup
          :ets.delete(@table, {user_id, timestamp})
          false
        end
      _ -> false
    end
  end

  # Server callbacks

  @impl true
  def init(_) do
    table = :ets.new(@table, [:named_table, :public, :set, {:read_concurrency, true}])
    {:ok, %{table: table}}
  end

  # Helpers
  defp expire_at, do: now() + @ttl_seconds
  defp now, do: :os.system_time(:second)
end
