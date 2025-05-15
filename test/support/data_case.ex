defmodule XIAM.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use XIAM.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias XIAM.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import XIAM.DataCase
      require Logger # Add require for Logger macros
    end
  end

  setup tags do
    # Ensure all dependencies are started before running tests
    {:ok, _} = Application.ensure_all_started(:ecto)
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    {:ok, _} = Application.ensure_all_started(:postgrex)
    {:ok, _} = Application.ensure_all_started(:xiam)

    # Perform Ecto Sandbox setup AFTER ensuring the app is started
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
    end

    :ok
  end

  # Called after each test
  def on_exit(_test_case_or_module, _context) do
    IO.puts("[DATACASE_ON_EXIT] Attempting to checkin DB connection for XIAM.Repo...")
    checkin_result = Ecto.Adapters.SQL.Sandbox.checkin(XIAM.Repo, [])
    IO.puts("[DATACASE_ON_EXIT] DB connection checkin result for XIAM.Repo: #{inspect(checkin_result)}")
    checkin_result # Return the result of the checkin
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{\w+}", message, fn key ->
        render_key(key, opts)
      end)
    end)
  end

  defp render_key(key, opts) do
    extracted_atom_key =
      key
      |> String.replace(~r"^%{|}$", "")
      |> String.to_atom()

    Keyword.fetch!(opts, extracted_atom_key)
    |> to_string()
  end
end
