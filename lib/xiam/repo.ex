defmodule XIAM.Repo do
  use Ecto.Repo,
    otp_app: :xiam,
    adapter: Ecto.Adapters.Postgres
    
  @doc """
  Paginates a query using the XIAM.Pagination module.
  
  See `XIAM.Pagination.paginate/2` for options.
  """
  def paginate(query, opts \\ []) do
    XIAM.Pagination.paginate(query, opts)
  end
end
