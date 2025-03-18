defmodule XIAM.Pagination do
  @moduledoc """
  Simple pagination utility functions for Ecto.
  """
  import Ecto.Query

  @doc """
  Paginates a query, returning a map with page details and the paginated items.
  
  ## Options
  
  * `:page` - The page number (starting from 1)
  * `:page_size` - Number of items per page
  
  ## Examples
  
      query = from(p in Post, order_by: [desc: p.inserted_at])
      Pagination.paginate(query, page: 2, page_size: 10)
  """
  def paginate(query, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 20)
    
    # Ensure page and page_size are positive integers
    page = max(1, page)
    page_size = max(1, page_size)
    
    # Get the total count of records
    total_count = XIAM.Repo.aggregate(query, :count, :id)
    
    # Calculate total pages
    total_pages = max(1, ceil(total_count / page_size))
    
    # Apply pagination to the query
    paginated_query = query
      |> limit(^page_size)
      |> offset(^((page - 1) * page_size))
    
    # Get the paginated items
    items = XIAM.Repo.all(paginated_query)
    
    # Build the pagination result
    %{
      items: items,
      page: page,
      page_size: page_size,
      total_count: total_count,
      total_pages: total_pages,
      has_next: page < total_pages,
      has_prev: page > 1
    }
  end
end
