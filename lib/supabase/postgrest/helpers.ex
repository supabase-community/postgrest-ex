defmodule Supabase.PostgREST.Helpers do
  @moduledoc """
  Helper functions for PostgREST operations
  """

  @doc """
  Get a header value from a headers list
  """
  def get_header(headers, key) when is_list(headers) do
    case List.keyfind(headers, key, 0) do
      {^key, value} -> value
      nil -> nil
    end
  end

  @doc """
  Get a query parameter value from a query list
  """
  def get_query_param(query, key) when is_list(query) do
    case List.keyfind(query, key, 0) do
      {^key, value} -> value
      nil -> nil
    end
  end
end
