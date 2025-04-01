defmodule XIAMWeb.API.ControllerHelpers do
  @moduledoc """
  Shared helper functions for API controllers to reduce code duplication.
  Provides standardized response formatting, common query parameter parsing,
  and pagination helpers.
  """

  @doc """
  Builds standard pagination parameters from request query params.
  """
  def pagination_params(params) do
    page = Map.get(params, "page", "1") |> parse_integer(1)
    per_page = Map.get(params, "per_page", "20") |> parse_integer(20)
    %{page: page, per_page: per_page}
  end

  @doc """
  Formats pagination information for API responses.
  """
  def pagination_info(page) do
    %{
      page: page.page || page.page_number,
      per_page: page.page_size,
      total_pages: page.total_pages || page.total_count,
      total_entries: page.total_count
    }
  end

  @doc """
  Extracts the user agent from request headers.
  """
  def get_user_agent(conn) do
    Enum.find_value(conn.req_headers, fn
      {"user-agent", value} -> value
      _ -> nil
    end)
  end

  @doc """
  Adds common request metadata to params (IP, user agent).
  """
  def add_request_metadata(conn, params) do
    # Format IP address properly for both tuples and other formats
    ip_string = format_ip_address(conn.remote_ip)
    
    params
    |> Map.put("ip_address", ip_string)
    |> Map.put("user_agent", get_user_agent(conn))
  end
  
  # Format IP address tuple to string
  defp format_ip_address(ip) when is_tuple(ip), do: ip |> Tuple.to_list() |> Enum.join(".")
  defp format_ip_address(ip), do: to_string(ip)

  @doc """
  Safely parses an integer with fallback.
  """
  def parse_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  def parse_integer(_, default), do: default

  @doc """
  Safely parses a boolean with fallback.
  """
  def parse_boolean("true"), do: true
  def parse_boolean("false"), do: false
  def parse_boolean(_), do: nil

  @doc """
  Builds filter parameters from request params based on allowed filters.
  """
  def build_filters(params, allowed_filters) do
    Enum.reduce(allowed_filters, %{}, fn {param_key, filter_key, parser}, acc ->
      case Map.get(params, param_key) do
        nil -> acc
        value -> 
          parsed = apply_parser(value, parser)
          if is_nil(parsed), do: acc, else: Map.put(acc, filter_key, parsed)
      end
    end)
  end

  defp apply_parser(value, :string), do: value
  defp apply_parser(value, :integer), do: parse_integer(value, nil)
  defp apply_parser(value, :boolean), do: parse_boolean(value)
  defp apply_parser(value, custom_parser) when is_function(custom_parser, 1), do: custom_parser.(value)
end