defmodule XIAMWeb.Plugs.CSPHeaderPlug do
  import Plug.Conn

  @csp "default-src 'self'; script-src 'self' 'unsafe-inline' https://unpkg.com; style-src 'self' 'unsafe-inline' https://unpkg.com; img-src 'self' data:; font-src 'self'; object-src 'none'; frame-ancestors 'none'; base-uri 'self';"

  def init(opts), do: opts

  def call(conn, _opts) do
    put_resp_header(conn, "content-security-policy", @csp)
  end
end
