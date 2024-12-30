defmodule Supabase.PostgREST.TransformBuilder do
  @moduledoc """
  Handles transformations applied to query results.

  This module provides functionality for ordering, limiting, and paginating query results. These transformations modify how data is structured or retrieved, enabling precise control over the format and amount of data returned.
  """

  alias Supabase.PostgREST.Builder

  @behaviour Supabase.PostgREST.TransformBuilder.Behaviour

  @doc """
  Limits the number of results returned by the query, optionally scoping this limit to a specific foreign table.

  ## Parameters
  - `builder`: The Builder instance.
  - `count`: The maximum number of results to return.
  - `opts`: Optional parameters, which may include a foreign table.

  ## Examples
      iex> PostgREST.limit(builder, 10)

  ## See also
  - Supabase query limits: https://supabase.com/docs/reference/javascript/using-filters#limit
  """
  @impl true
  def limit(%Builder{} = f, count, opts \\ []) do
    if foreign = Keyword.get(opts, :foreign_table) do
      Builder.add_query_param(f, "#{foreign}.limit", to_string(count))
    else
      Builder.add_query_param(f, "limit", to_string(count))
    end
  end

  @doc """
  Order the query result by `column`.
  You can call this method multiple times to order by multiple columns.
  You can order referenced tables, but it only affects the ordering of the parent table if you use `!inner` in the query.

  ## Parameters
  - `builder`: The Builder instance.
  - `column`: The column by which to order the results.
  - `opts`: Options such as direction (`:asc` or `:desc`) and null handling (`:null_first` or `:null_last`).

  ## Examples
      iex> PostgREST.order(builder, "created_at", asc: true, null_first: false)

  ## See also
  - Supabase ordering results: https://supabase.com/docs/reference/javascript/using-filters#order
  """
  @impl true
  def order(%Builder{} = f, column, opts \\ []) do
    order = if opts[:asc], do: "asc", else: "desc"
    nulls_first = if opts[:null_first], do: "nullsfirst", else: "nullslast"
    foreign = Keyword.get(opts, :foreign_table)
    key = if foreign, do: "#{foreign}.order", else: "order"

    if curr = f.params[key] do
      Builder.add_query_param(f, key, "#{curr},#{column}.#{order}.#{nulls_first}")
    else
      Builder.add_query_param(f, key, "#{column}.#{order}.#{nulls_first}")
    end
  end

  defguardp is_number(a, b)
            when Kernel.or(
                   Kernel.and(is_integer(a), is_integer(b)),
                   Kernel.and(is_float(a), is_float(b))
                 )

  @doc """
  Limit the query result by starting at an offset `from` and ending at the offset `to`. Only records within this range are returned.
  This respects the query order and if there is no order clause the range could behave unexpectedly.
  The `from` and `to` values are 0-based and inclusive: `range(1, 3)` will include the second, third and fourth rows of the query.

  ## Parameters
  - `builder`: The Builder instance.
  - `from`: The starting index for the results.
  - `to`: The ending index for the results, inclusive.

  ## Examples
      iex> PostgREST.range(builder, 0, 10)

  ## See also
  - Supabase range queries: https://supabase.com/docs/reference/javascript/using-filters#range
  """
  @impl true
  def range(%Builder{} = f, from, to, opts \\ []) when is_number(from, to) do
    if foreign = Keyword.get(opts, :foreign_table) do
      f
      |> Builder.add_query_param("#{foreign}.offset", to_string(from))
      |> Builder.add_query_param("#{foreign}.limit", to_string(to - from + 1))
    else
      f
      |> Builder.add_query_param("offset", to_string(from))
      |> Builder.add_query_param("limit", to_string(to - from + 1))
    end
  end

  @doc """
  Return `data` as a single object instead of an array of objects.
  Query result must be one row (e.g. using `.limit(1)`), otherwise this returns an error.

  ## Parameters
  - `builder`: The Builder instance to modify.

  ## Examples
      iex> PostgREST.single(builder)

  ## See also
  - Supabase single row mode: https://supabase.com/docs/reference/javascript/using-filters#single-row
  """
  @impl true
  def single(%Builder{} = b) do
    Supabase.PostgREST.with_custom_media_type(b, :pgrst_object)
  end

  @doc """
  Return `data` as a single object instead of an array of objects.
  Query result must be one row (e.g. using `.limit(1)`), otherwise this returns an error.

  ## Parameters
  - `builder`: The Builder instance to modify.

  ## Examples
      iex> PostgREST.single(builder)

  ## See also
  - Supabase single row mode: https://supabase.com/docs/reference/javascript/using-filters#single-row
  """
  @impl true
  def maybe_single(%Builder{} = b) when b.method == :get do
    Supabase.PostgREST.with_custom_media_type(b, :json)
  end

  def maybe_single(%Builder{} = b) do
    Supabase.PostgREST.with_custom_media_type(b, :pgrst_object)
  end
end
