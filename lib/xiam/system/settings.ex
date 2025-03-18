defmodule XIAM.System.Settings do
  @moduledoc """
  The Settings context provides functionality to manage system-wide settings
  for the XIAM application. Settings are stored in the database and cached
  for performance.
  """

  import Ecto.Query
  alias XIAM.Repo
  alias XIAM.System.Setting
  alias XIAM.Audit

  # ETS table for caching settings
  @ets_table :xiam_settings_cache

  @doc """
  Initializes the settings cache on application startup.
  """
  def init_cache do
    # Create ETS table if it doesn't exist
    if :ets.info(@ets_table) == :undefined do
      :ets.new(@ets_table, [:named_table, :set, :public, read_concurrency: true])
    end

    # Load all settings into cache
    get_all_settings()
    |> Enum.each(fn setting ->
      :ets.insert(@ets_table, {setting.key, parsed_value(setting)})
    end)
  end
  
  @doc """
  Refreshes the settings cache by reloading all settings from the database.
  Should be called after a setting is updated.
  """
  def refresh_cache do
    # Simply re-initialize the cache
    init_cache()
  end

  @doc """
  Returns a list of all system settings.

  ## Examples

      iex> list_settings()
      [%Setting{}, ...]

  """
  def list_settings do
    Setting
    |> order_by(asc: :category, asc: :key)
    |> Repo.all()
  end

  @doc """
  Returns settings filtered by category.

  ## Examples

      iex> get_settings_by_category("security")
      [%Setting{}, ...]

  """
  def get_settings_by_category(category) when is_binary(category) do
    Setting
    |> where([s], s.category == ^category)
    |> order_by(asc: :key)
    |> Repo.all()
  end

  @doc """
  Gets a single setting by key.

  Returns nil if the setting does not exist.

  ## Examples

      iex> get_setting_by_key("mfa_required")
      %Setting{}

      iex> get_setting_by_key("nonexistent")
      nil

  """
  def get_setting_by_key(key) when is_binary(key) do
    Repo.get_by(Setting, key: key)
  end

  @doc """
  Creates a new setting.

  ## Examples

      iex> create_setting(%{key: "mfa_required", value: "true"})
      {:ok, %Setting{}}

  """
  def create_setting(attrs, actor \\ nil, conn \\ nil) do
    result =
      %Setting{}
      |> Setting.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, setting} ->
        # Update cache
        :ets.insert(@ets_table, {setting.key, parsed_value(setting)})

        # Audit log
        Audit.log_action(
          "create_setting",
          actor || :system,
          "setting",
          setting.id,
          %{key: setting.key, value: setting.value},
          conn
        )

        result

      _ ->
        result
    end
  end

  @doc """
  Updates a setting.

  ## Examples

      iex> update_setting(setting, %{value: "false"})
      {:ok, %Setting{}}

  """
  def update_setting(%Setting{} = setting, attrs, actor \\ nil, conn \\ nil) do
    result =
      setting
      |> Setting.changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated_setting} ->
        # Update cache
        :ets.insert(@ets_table, {updated_setting.key, parsed_value(updated_setting)})

        # Audit log
        Audit.log_action(
          "update_setting",
          actor || :system,
          "setting",
          setting.id,
          %{key: setting.key, old_value: setting.value, new_value: updated_setting.value},
          conn
        )

        result

      _ ->
        result
    end
  end

  @doc """
  Deletes a setting.

  ## Examples

      iex> delete_setting(setting)
      {:ok, %Setting{}}

  """
  def delete_setting(%Setting{} = setting, actor \\ nil, conn \\ nil) do
    result = Repo.delete(setting)

    case result do
      {:ok, deleted_setting} ->
        # Remove from cache
        :ets.delete(@ets_table, deleted_setting.key)

        # Audit log
        Audit.log_action(
          "delete_setting",
          actor || :system,
          "setting",
          setting.id,
          %{key: setting.key, value: setting.value},
          conn
        )

        result

      _ ->
        result
    end
  end

  @doc """
  Gets a setting value by key, using cache for performance.

  ## Examples

      iex> get_value("mfa_required")
      true

      iex> get_value("nonexistent")
      nil

  """
  def get_value(key) when is_binary(key) do
    case :ets.lookup(@ets_table, key) do
      [{^key, value}] ->
        value

      [] ->
        # Cache miss, try to load from DB
        case get_setting_by_key(key) do
          nil ->
            nil

          setting ->
            value = parsed_value(setting)
            :ets.insert(@ets_table, {key, value})
            value
        end
    end
  end

  @doc """
  Gets a setting value by key with a provided default if not found.

  ## Examples

      iex> get_value("mfa_required", false)
      true

      iex> get_value("nonexistent", "default")
      "default"

  """
  def get_value(key, default) when is_binary(key) do
    case get_value(key) do
      nil -> default
      value -> value
    end
  end

  @doc """
  Sets a setting value by key, creating it if it doesn't exist.

  ## Examples

      iex> set_value("mfa_required", true, "security")
      {:ok, %Setting{}}

  """
  def set_value(key, value, category \\ "general", actor \\ nil, conn \\ nil) when is_binary(key) do
    string_value = to_string(value)

    case get_setting_by_key(key) do
      nil ->
        # Create new setting
        create_setting(
          %{key: key, value: string_value, category: category, data_type: detect_type(value)},
          actor,
          conn
        )

      setting ->
        # Update existing setting
        update_setting(setting, %{value: string_value}, actor, conn)
    end
  end

  @doc """
  Returns all available setting categories.
  """
  def list_categories do
    Setting
    |> distinct(true)
    |> select([s], s.category)
    |> order_by(asc: :category)
    |> Repo.all()
  end

  @doc """
  Returns all settings in a map format for easy access.
  """
  def get_all_settings_map do
    list_settings()
    |> Enum.reduce(%{}, fn setting, acc ->
      Map.put(acc, setting.key, parsed_value(setting))
    end)
  end

  # Private functions

  # Convert string values to actual Elixir data types based on the setting's data_type
  defp parsed_value(%Setting{} = setting) do
    case setting.data_type do
      "boolean" ->
        String.downcase(setting.value) == "true"

      "integer" ->
        String.to_integer(setting.value)

      "float" ->
        String.to_float(setting.value)

      "json" ->
        case Jason.decode(setting.value) do
          {:ok, decoded} -> decoded
          _ -> setting.value
        end

      _ ->
        setting.value
    end
  end

  # Detect the data type of a value for storing
  defp detect_type(value) when is_boolean(value), do: "boolean"
  defp detect_type(value) when is_integer(value), do: "integer"
  defp detect_type(value) when is_float(value), do: "float"
  defp detect_type(value) when is_map(value) or is_list(value), do: "json"
  defp detect_type(_), do: "string"

  # Get all settings from DB
  defp get_all_settings do
    Setting
    |> order_by(asc: :key)
    |> Repo.all()
  end
end
