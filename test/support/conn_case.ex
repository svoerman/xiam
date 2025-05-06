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
      # The default endpoint for testing
      @endpoint XIAMWeb.Endpoint

      use XIAMWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import XIAMWeb.ConnCase
    end
  end

  setup tags do
    # Initialize ETS tables to avoid lookup errors during tests
    XIAM.ETSTestHelper.ensure_ets_tables_exist()
    XIAM.ETSTestHelper.initialize_endpoint_config()
    
    # Use the improved sandbox setup from DataCase
    XIAM.DataCase.setup_sandbox(tags)
    
    # Build a connection but don't set any default headers
    # Individual tests can set the appropriate headers
    conn = Phoenix.ConnTest.build_conn()
    
    {:ok, conn: conn}
  end
end
