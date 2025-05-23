defmodule XIAMWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :xiam

  # Ensure ETS tables needed by the endpoint are created
  # This is useful for tests that need the tables but don't have a proper Phoenix setup
  def ensure_ets_tables do
    for table_name <- [:render_errors, :secret_key_base, :pubsub, :live_view, :telemetry_handler] do
      try do
        if :ets.whereis(table_name) == :undefined do
          :ets.new(table_name, [:named_table, :public])
        end
      catch
        _, _ -> :ok # Table already exists
      end
    end
  end

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_xiam_key",
    signing_salt: "5sqVqtFT",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :xiam,
    gzip: false,
    only: XIAMWeb.static_paths()

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :xiam
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug Pow.Plug.Session, otp_app: :xiam
  plug XIAMWeb.Router
end
