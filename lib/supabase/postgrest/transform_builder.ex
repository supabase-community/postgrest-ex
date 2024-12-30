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

  @doc """
  Return `data` as a string in CSV format.

  ## Examples
      iex> PostgREST.csv(builder)
      %Builder{headers: %{"accept" => "text/csv"}}

  ## See also
  https://supabase.com/docs/reference/javascript/db-csv
  """
  @impl true
  def csv(%Builder{} = b) do
    Builder.add_request_header(b, "accept", "text/csv")
  end

  @doc """
  Return `data` as an object in [GeoJSON](https://geojson.org) format.

  ## Examples
      iex> PostgREST.csv(builder)
      %Builder{headers: %{"accept" => "application/geo+json"}}
  """
  @impl true
  def geojson(%Builder{} = b) do
    Builder.add_request_header(b, "accept", "application/geo+json")
  end

  @explain_default [
    analyze: false,
    verbose: false,
    settings: false,
    buffers: false,
    wal: false
  ]

  @doc """
  Return `data` as the EXPLAIN plan for the query.
  You need to enable the [db_plan_enabled](https://supabase.com/docs/guides/database/debugging-performance#enabling-explain) setting before using this method.

  ## Params
  - `options`: options as a keyword list, these are the possibilities:
    - `analyze`: boolean, defaults to `false`
    - `verbose`: boolean, defaults to `false`
    - `settings`: boolean, default to `false`
    - `buffers`: boolean, defaults to `false`
    - `wal`: boolean, default to `false`
    - `format`: `:json` or `:text`, defaults to `:text`

  ## Examples
      iex> PostgREST.explain(builder, analyze: true, format: :json, wal: false)
      %Builder{}

  ## See also
  https://supabase.com/docs/reference/javascript/explain
  """
  @impl true
  def explain(%Builder{} = b, opts \\ []) do
    format =
      opts
      |> Keyword.get(:format, :text)
      |> then(fn format ->
        if format in [:json, :text] do
          "+#{format};"
        else
          "+text;"
        end
      end)

    opts =
      @explain_default
      |> Keyword.merge(opts)
      |> Enum.filter(&elem(&1, 1))
      |> Enum.map_join("|", &elem(&1, 0))
      |> then(&"options:#{&1}")

    # postgrest-ex sends always only one Accept header
    # and always sets a default (application/json)
    for_mediatype = "for=#{b.headers["accept"]}"

    plan = "application/vnd.pgrst.plan#{format};#{for_mediatype};#{opts}"

    Builder.add_request_header(b, "accept", plan)
  end

  @doc """
  Rollback the query. `data` will still be returned, but the query is not committed.

  ## Examples
      iex> PostgREST.rollback(builder)
      %Builder{headers: %{"prefer" => "tx=rollback"}}
  """
  @impl true
  def rollback(%Builder{} = b) do
    if prefer = b.headers["prefer"] do
      Builder.add_request_header(b, "prefer", "#{prefer},tx=rollback")
    else
      Builder.add_request_header(b, "prefer", "tx=rollback")
    end
  end

  @doc """
  Perform a SELECT on the query result.
   
  By default, `.insert()`, `.update()`, `.upsert()`, and `.delete()` do not
  return modified rows. By calling this method, modified rows are returned in
  `data`.

  **Do not** confuse with the `Supabase.PostgREST.QueryBuilder.select/3` function.

  ## Params
  If called without additional arguments (besides builder), it will fallback to select all
  relation (table) columns (with `"*"`), otherwise you can pass a list of strings representing
  the columns to be selected

  ## Examples
      iex> PostgREST.insert(builder, %{foo: :bar}) |> PostgREST.returning(~w(id foo))

  ## See also
  https://supabase.com/docs/reference/javascript/db-modifiers-select
  """
  @impl true
  def returning(%Builder{} = b) do
    prefer = if p = b.headers["prefer"], do: p <> ",", else: ""

    b
    |> Builder.add_query_param("select", "*")
    |> Builder.add_request_header("prefer", "#{prefer}return=representation")
  end

  @impl true
  def returning(%Builder{} = b, columns) when is_list(columns) do
    cols =
      Enum.map_join(columns, ",", fn c ->
        if String.match?(c, ~r/\"/), do: c, else: String.trim(c)
      end)

    prefer = if p = b.headers["prefer"], do: p <> ",", else: ""

    b
    |> Builder.add_query_param("select", cols)
    |> Builder.add_request_header("prefer", "#{prefer}return=representation")
  end
end
