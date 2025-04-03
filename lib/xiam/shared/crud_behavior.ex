defmodule XIAM.Shared.CRUDBehavior do
  @moduledoc """
  Defines a common behavior for CRUD operations to reduce duplication across context modules.
  This module can be used with `use XIAM.Shared.CRUDBehavior` to generate standard CRUD functions.
  """

  defmacro __using__(opts) do
    repo = Keyword.get(opts, :repo, XIAM.Repo)
    schema = Keyword.fetch!(opts, :schema)
    preloads = Keyword.get(opts, :preloads, [])
    pagination_enabled = Keyword.get(opts, :pagination, false)
    search_field = Keyword.get(opts, :search_field)
    sort_fields = Keyword.get(opts, :sort_fields, [])

    quote do
      import Ecto.Query, warn: false

      # Schema to use for this context
      @schema unquote(schema)
      @preloads unquote(preloads)
      @pagination unquote(pagination_enabled)
      @search_field unquote(search_field)
      @sort_fields unquote(sort_fields)
      @repo unquote(repo)

      @doc """
      Lists all records with optional filtering, pagination, sorting.
      """
      def list_all(filters \\ %{}, pagination_params \\ %{}) do
        query = @schema

        # Apply any filters from the filters map
        query = apply_filters(query, filters)

        # Apply search if configured and provided
        query = if @search_field && Map.has_key?(filters, :search) do
          search_term = "%#{filters.search}%"
          field = @search_field
          where(query, [q], ilike(field(q, ^field), ^search_term))
        else
          query
        end

        # Apply sorting if provided and configured
        query = apply_sorting(query, Map.get(filters, :sort_by), Map.get(filters, :sort_order))

        # Apply preloads if configured
        query = if @preloads != [], do: preload(query, ^@preloads), else: query

        # Apply pagination if enabled and params provided
        if @pagination && pagination_params != %{} do
          # Convert expected pagination param keys (strings OR atoms) to atom keys safely
          pagination_opts =
            Enum.reduce(pagination_params, [], fn {key, val}, acc ->
              cond do
                key == "page" or key == :page -> [{:page, val} | acc]
                key == "page_size" or key == :page_size -> [{:page_size, val} | acc]
                true -> acc # Ignore other keys
              end
            end)

          # Get paginated results
          XIAM.Pagination.paginate(query, pagination_opts)
        else
          @repo.all(query)
        end
      end

      @doc """
      Gets a single record with preloads.
      Returns nil if not found.
      """
      def get(id) do
        query = from(q in @schema, where: q.id == ^id)
        query = if @preloads != [], do: preload(query, ^@preloads), else: query
        @repo.one(query)
      end

      @doc """
      Gets a single record with preloads.
      Raises Ecto.NoResultsError if not found.
      """
      def get!(id) do
        query = from(q in @schema, where: q.id == ^id)
        query = if @preloads != [], do: preload(query, ^@preloads), else: query
        @repo.one!(query)
      end

      @doc """
      Creates a record with the given attributes.
      """
      def create(attrs) do
        %@schema{}
        |> @schema.changeset(attrs)
        |> @repo.insert()
      end

      @doc """
      Updates a record with the given attributes.
      """
      def update(record, attrs) do
        record
        |> @schema.changeset(attrs)
        |> @repo.update()
      end

      @doc """
      Deletes a record.
      """
      def delete(record) do
        @repo.delete(record)
      end

      # Override these in your context module to customize behavior

      @doc """
      Apply filters to a query. Override this in your context module for custom filtering.
      """
      def apply_filters(query, _filters), do: query

      @doc """
      Apply sorting to a query based on sort_by and sort_order.
      """
      def apply_sorting(query, sort_by, sort_order) do
        if sort_by && sort_by in @sort_fields do
          direction = if sort_order == :desc, do: :desc, else: :asc
          order_by(query, [{^direction, ^sort_by}])
        else
          # Default sorting if defined
          query
        end
      end

      # Allow overriding in the using module
      defoverridable [
        list_all: 2,
        get: 1,
        get!: 1,
        create: 1,
        update: 2,
        delete: 1,
        apply_filters: 2,
        apply_sorting: 3
      ]
    end
  end
end
