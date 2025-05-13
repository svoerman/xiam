defmodule XIAMWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use XIAMWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      require XIAMWeb.Router # Ensure router is compiled before helpers are imported
      # The default endpoint for testing
      @endpoint XIAMWeb.Endpoint

      use XIAMWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import XIAMWeb.Router.Helpers
      import XIAMWeb.ConnCase
    end
  end

  setup tags do
    # Ensure the :xiam application and its dependencies are started.
    Application.ensure_all_started(:xiam)

    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(XIAM.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    # Ensure Phoenix endpoint ETS tables are initialized for tests needing them
    XIAM.ETSTestHelper.initialize_endpoint_config()
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Logs in the given user using Pow in test connection.
  Prepares the connection state for LiveView tests by initializing the session,
  loading Pow's session config, creating the session token, recycling the connection,
  and then reloading the session to ensure it's active on the conn.
  """
  def log_in_user(conn, user) do
    conn
    |> Pow.Plug.assign_current_user(user, otp_app: :xiam)
    |> Phoenix.ConnTest.init_test_session(%{"pow_user_id" => user.id})
  end
end
