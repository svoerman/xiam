defmodule XIAM.System.SettingsTest do
  use XIAM.DataCase

  alias XIAM.System.Setting
  alias XIAM.System.Settings
  alias XIAM.Repo

  describe "settings management" do
    setup do
      # Explicitly ensure repo is available
      case Process.whereis(XIAM.Repo) do
        nil ->
          # Repo is not started, try to start it explicitly
          {:ok, _} = Application.ensure_all_started(:ecto_sql)
          {:ok, _} = XIAM.Repo.start_link([])
          # Set sandbox mode
          Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
        _ -> 
          :ok
      end
      
      # Create the ETS table if it doesn't exist
      if :ets.info(:xiam_settings_cache) == :undefined do
        :ets.new(:xiam_settings_cache, [:named_table, :set, :public, read_concurrency: true])
      end
      
      :ok
    end
    test "list_settings/0 returns all settings" do
      # Insert a test setting
      %Setting{key: "test_key", value: "test_value", description: "Test setting"}
      |> Repo.insert!()

      settings = Settings.list_settings()
      assert length(settings) >= 1
      assert Enum.any?(settings, fn s -> s.key == "test_key" end)
    end

    test "get_setting_by_key/1 returns a setting by key" do
      # Insert a test setting
      setting = %Setting{key: "get_test_key", value: "test_value", description: "Test setting"}
      |> Repo.insert!()

      retrieved_setting = Settings.get_setting_by_key("get_test_key")
      assert retrieved_setting.id == setting.id
      assert retrieved_setting.key == "get_test_key"
      assert retrieved_setting.value == "test_value"
    end

    test "get_setting_by_key/1 returns nil for non-existent key" do
      assert Settings.get_setting_by_key("non_existent_key") == nil
    end

    test "get_setting_value/2 returns the value of a setting" do
      # Insert a test setting
      %Setting{key: "value_test_key", value: "test_value", description: "Test setting"}
      |> Repo.insert!()

      value = Settings.get_value("value_test_key")
      assert value == "test_value"
    end

    test "get_setting_value/2 returns the default value for non-existent key" do
      value = Settings.get_value("non_existent_key", "default_value")
      assert value == "default_value"
    end

    test "create_setting/1 creates a new setting" do
      attrs = %{
        key: "create_test_key",
        value: "new_value",
        description: "New test setting"
      }

      assert {:ok, %Setting{} = setting} = Settings.create_setting(attrs)
      assert setting.key == "create_test_key"
      assert setting.value == "new_value"
      assert setting.description == "New test setting"
    end

    test "update_setting_by_key/2 updates an existing setting" do
      # Insert a test setting
      %Setting{key: "update_test_key", value: "original_value", description: "Test setting"}
      |> Repo.insert!()

      assert {:ok, %Setting{} = setting} = Settings.update_setting_by_key("update_test_key", "updated_value")
      assert setting.key == "update_test_key"
      assert setting.value == "updated_value"
    end

    test "update_setting_by_key/2 returns error for non-existent key" do
      assert {:error, :not_found} = Settings.update_setting_by_key("new_key_from_update", "new_value")
    end

    test "delete_setting/1 deletes a setting" do
      # Insert a test setting
      setting = %Setting{key: "delete_test_key", value: "value", description: "Test setting"}
      |> Repo.insert!()

      assert {:ok, %Setting{}} = Settings.delete_setting(setting)
      assert Settings.get_setting_by_key("delete_test_key") == nil
    end

    test "upsert_setting/1 creates or updates a setting" do
      # Test creating a new setting
      attrs = %{
        key: "upsert_test_key",
        value: "upsert_value",
        description: "Upsert test setting"
      }

      assert {:ok, %Setting{} = setting} = Settings.upsert_setting(attrs)
      assert setting.key == "upsert_test_key"
      assert setting.value == "upsert_value"

      # Test updating the setting
      updated_attrs = %{
        key: "upsert_test_key",
        value: "updated_upsert_value",
        description: "Updated description"
      }

      assert {:ok, %Setting{} = updated_setting} = Settings.upsert_setting(updated_attrs)
      assert updated_setting.key == "upsert_test_key"
      assert updated_setting.value == "updated_upsert_value"
      assert updated_setting.description == "Updated description"
    end
  end

  describe "settings cache" do
    setup do
      # Explicitly ensure repo is available
      case Process.whereis(XIAM.Repo) do
        nil ->
          # Repo is not started, try to start it explicitly
          {:ok, _} = Application.ensure_all_started(:ecto_sql)
          {:ok, _} = XIAM.Repo.start_link([])
          # Set sandbox mode
          Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
        _ -> 
          :ok
      end
      
      # Create the ETS table if it doesn't exist
      if :ets.info(:xiam_settings_cache) == :undefined do
        :ets.new(:xiam_settings_cache, [:named_table, :set, :public, read_concurrency: true])
      end
      
      # Clear cache before tests
      :ok = Settings.clear_cache()
      :ok
    end

    test "get_cached_setting/2 returns cached setting" do
      # Insert a test setting
      %Setting{key: "cache_test_key", value: "cache_value", description: "Cache test"}
      |> Repo.insert!()

      # Load the setting into cache
      Settings.init_cache()

      # Get from cache
      value = Settings.get_cached_setting("cache_test_key")
      assert value == "cache_value"

      # Update the setting in the database but not in cache
      Repo.get_by(Setting, key: "cache_test_key")
      |> Ecto.Changeset.change(value: "new_db_value")
      |> Repo.update!()

      # Cache should still have the old value
      value = Settings.get_cached_setting("cache_test_key")
      assert value == "cache_value"

      # After refresh, cache should have new value
      Settings.refresh_cache()
      value = Settings.get_cached_setting("cache_test_key")
      assert value == "new_db_value"
    end

    test "get_cached_setting/2 returns default value for non-cached setting" do
      value = Settings.get_cached_setting("non_cached_key", "default_cache_value")
      assert value == "default_cache_value"
    end

    test "refresh_cache/0 updates all cached settings" do
      # Insert test settings
      %Setting{key: "refresh_test_key1", value: "value1", description: "Refresh test 1"}
      |> Repo.insert!()

      %Setting{key: "refresh_test_key2", value: "value2", description: "Refresh test 2"}
      |> Repo.insert!()

      # Initialize cache
      Settings.init_cache()

      # Update both settings in database
      Repo.get_by(Setting, key: "refresh_test_key1")
      |> Ecto.Changeset.change(value: "new_value1")
      |> Repo.update!()

      Repo.get_by(Setting, key: "refresh_test_key2")
      |> Ecto.Changeset.change(value: "new_value2")
      |> Repo.update!()

      # Refresh cache
      Settings.refresh_cache()

      # Verify both settings are updated in cache
      assert Settings.get_cached_setting("refresh_test_key1") == "new_value1"
      assert Settings.get_cached_setting("refresh_test_key2") == "new_value2"
    end

    test "clear_cache/0 removes all cached settings" do
      # Insert a test setting
      %Setting{key: "clear_test_key", value: "clear_value", description: "Clear test"}
      |> Repo.insert!()

      # Initialize cache
      Settings.init_cache()

      # Verify setting is in cache
      assert Settings.get_cached_setting("clear_test_key") == "clear_value"

      # Clear cache
      Settings.clear_cache()

      # Setting should no longer be in database cache
      Repo.delete_all(XIAM.System.Setting)
      Settings.refresh_cache()
      assert Settings.get_cached_setting("clear_test_key", "default") == "default"
    end
  end
end