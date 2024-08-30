defmodule Supabase.PostgREST do
  @moduledoc """
  Provides a suite of functions to interact with a Supabase PostgREST API, allowing
  for construction and execution of queries using a fluent interface. This module is designed
  to facilitate the building of complex queries and their execution in the context of a Supabase
  database application.

  For detailed usage examples and more information, refer to the official Supabase documentation:
  https://supabase.com/docs
  """

  import Kernel, except: [not: 1, and: 2, or: 2, in: 2]

  alias Supabase.Client
  alias Supabase.PostgREST.Error
  alias Supabase.PostgREST.FilterBuilder
  alias Supabase.PostgREST.QueryBuilder

  @behaviour Supabase.PostgRESTBehaviour

  @doc """
  Initializes a `QueryBuilder` for a specified table and client.

  ## Parameters
  - `client`: The Supabase client used for authentication and configuration.
  - `table`: The database table name as a string.

  ## Examples
      iex> PostgREST.from(client, "users")
      %QueryBuilder{}

  ## See also
  - Supabase documentation on initializing queries: https://supabase.com/docs/reference/javascript/from
  """
  @impl true
  def from(%Client{} = client, table) do
    QueryBuilder.new(table, client)
  end

  @doc """
  Selects records from a table. You can specify specific columns or use '*' for all columns.
  Options such as counting results and specifying return types can be configured.

  ## Parameters
  - `query_builder`: The QueryBuilder instance.
  - `columns`: A list of column names to fetch or '*' for all columns.
  - `opts`: Options such as `:count` and `:returning`.

  ## Examples
      iex> PostgREST.select(query_builder, "*", count: :exact, returning: true)

  ## See also
  - Supabase select queries: https://supabase.com/docs/reference/javascript/select
  """
  @impl true
  def select(query_builder, columns, opts \\ [])

  def select(%QueryBuilder{} = q, "*", opts) do
    count = Keyword.get(opts, :count, :exact)
    returning = Keyword.get(opts, :returning, false)

    q
    |> QueryBuilder.change_method(:get)
    |> QueryBuilder.add_param("select", "*")
    |> QueryBuilder.add_header("Prefer", "count=#{count}")
    |> maybe_return(returning)
    |> FilterBuilder.from_query_builder()
  end

  def select(%QueryBuilder{} = q, columns, opts)
      when is_list(columns) do
    count = Keyword.get(opts, :count, :exact)
    returning = Keyword.get(opts, :returning, false)

    q
    |> QueryBuilder.change_method(:get)
    |> QueryBuilder.add_param("select", Enum.join(columns, ","))
    |> QueryBuilder.add_header("Prefer", "count=#{count}")
    |> maybe_return(returning)
    |> FilterBuilder.from_query_builder()
  end

  defp maybe_return(q, true), do: QueryBuilder.change_method(q, :get)
  defp maybe_return(q, false), do: QueryBuilder.change_method(q, :head)

  @doc """
  Inserts new records into the database. Supports conflict resolution and specifying how the
  result should be returned.

  ## Parameters
  - `query_builder`: The QueryBuilder to use.
  - `data`: The data to be inserted, typically a map or a list of maps.
  - `opts`: Options like `:on_conflict`, `:returning`, and `:count`.

  ## Examples
      iex> PostgREST.insert(query_builder, %{name: "John"}, on_conflict: "name", returning: :minimal)

  ## See also
  - Supabase documentation on inserts: https://supabase.com/docs/reference/javascript/insert
  """
  @impl true
  def insert(%QueryBuilder{} = q, data, opts \\ []) do
    on_conflict = Keyword.get(opts, :on_conflict)
    on_conflict = if on_conflict, do: "on_conflict=#{on_conflict}"
    upsert = if on_conflict, do: "resolution=merge-duplicates"
    returning = Keyword.get(opts, :returning, :representation)
    count = Keyword.get(opts, :count, :exact)
    prefer = ["return=#{returning}", "count=#{count}", on_conflict, upsert]
    prefer = Enum.join(Enum.reject(prefer, &is_nil/1), ",")

    case Jason.encode(data) do
      {:ok, body} ->
        q
        |> QueryBuilder.change_method(:post)
        |> QueryBuilder.add_header("Prefer", prefer)
        |> QueryBuilder.add_param("on_conflict", on_conflict)
        |> QueryBuilder.change_body(body)
        |> FilterBuilder.from_query_builder()

      _err ->
        FilterBuilder.new()
    end
  end

  @doc """
  Upserts data into a table, allowing for conflict resolution and specifying return options.

  ## Parameters
  - `query_builder`: The QueryBuilder to use.
  - `data`: The data to upsert, typically a map or a list of maps.
  - `opts`: Options like `:on_conflict`, `:returning`, and `:count`.

  ## Examples
      iex> PostgREST.upsert(query_builder, %{name: "Jane"}, on_conflict: "name", returning: :representation)

  ## See also
  - Supabase documentation on upserts: https://supabase.com/docs/reference/javascript/upsert
  """
  @impl true
  def upsert(%QueryBuilder{} = q, data, opts \\ []) do
    on_conflict = Keyword.get(opts, :on_conflict)
    returning = Keyword.get(opts, :returning, :representation)
    count = Keyword.get(opts, :count, :exact)

    prefer =
      Enum.join(["resolution=merge-duplicates", "return=#{returning}", "count=#{count}"], ",")

    case Jason.encode(data) do
      {:ok, body} ->
        q
        |> QueryBuilder.change_method(:post)
        |> QueryBuilder.add_header("Prefer", prefer)
        |> QueryBuilder.add_param("on_conflict", on_conflict)
        |> QueryBuilder.change_body(body)
        |> FilterBuilder.from_query_builder()

      _err ->
        FilterBuilder.new()
    end
  end

  @doc """
  Deletes records from a table based on the conditions specified in the QueryBuilder.

  ## Parameters
  - `query_builder`: The QueryBuilder to use.
  - `opts`: Options such as `:returning` and `:count`.

  ## Examples
      iex> PostgREST.delete(query_builder, returning: :representation)

  ## See also
  - Supabase documentation on deletes: https://supabase.com/docs/reference/javascript/delete
  """
  @impl true
  def delete(%QueryBuilder{} = q, opts \\ []) do
    returning = Keyword.get(opts, :returning, :representation)
    count = Keyword.get(opts, :count, :exact)
    prefer = Enum.join(["return=#{returning}", "count=#{count}"], ",")

    q
    |> QueryBuilder.change_method(:delete)
    |> QueryBuilder.add_header("Prefer", prefer)
    |> FilterBuilder.from_query_builder()
  end

  @doc """
  Updates existing records in the database. Allows specifying return options and how the update is counted.

  ## Parameters
  - `query_builder`: The QueryBuilder to use.
  - `data`: The new data for the update, typically a map or list of maps.
  - `opts`: Options such as `:returning` and `:count`.

  ## Examples
      iex> PostgREST.update(query_builder, %{name: "Doe"}, returning: :representation)

  ## See also
  - Supabase documentation on updates: https://supabase.com/docs/reference/javascript/update
  """
  @impl true
  def update(%QueryBuilder{} = q, data, opts \\ []) do
    returning = Keyword.get(opts, :returning, :representation)
    count = Keyword.get(opts, :count, :exact)
    prefer = Enum.join(["return=#{returning}", "count=#{count}"], ",")

    case Jason.encode(data) do
      {:ok, body} ->
        q
        |> QueryBuilder.change_method(:patch)
        |> QueryBuilder.add_header("Prefer", prefer)
        |> QueryBuilder.change_body(body)
        |> FilterBuilder.from_query_builder()

      _err ->
        FilterBuilder.new()
    end
  end

  @impl true
  def filter(%FilterBuilder{} = f, column, op, value) do
    FilterBuilder.add_param(f, column, "#{op}.#{value}")
  end

  @doc """
  Applies an "AND" condition to a query, allowing multiple conditions on different columns.
  This can also be scoped to a foreign table if specified.

  ## Parameters
  - `filter_builder`: The FilterBuilder instance.
  - `columns`: A list of conditions that should all be met.
  - `opts`: Optional parameters, which can include specifying a foreign table.

  ## Examples
      iex> PostgREST.and(filter_builder, ["age > 18", "status = 'active'"])

  ## See also
  - Supabase logical operations: https://supabase.com/docs/reference/javascript/using-filters#logical-operators
  """
  @impl true
  def unquote(:and)(%FilterBuilder{} = f, columns, opts \\ []) do
    columns = Enum.join(columns, ",")

    if foreign = Keyword.get(opts, :foreign_table) do
      FilterBuilder.add_param(f, "#{foreign}.and", "(#{columns})")
    else
      FilterBuilder.add_param(f, "and", "(#{columns})")
    end
  end

  @doc """
  Applies an "OR" condition to a query, combining multiple conditions on different columns
  where at least one condition must be met. This can also be scoped to a foreign table.

  ## Parameters
  - `filter_builder`: The FilterBuilder instance.
  - `columns`: A list of conditions where at least one should be met.
  - `opts`: Optional parameters, which can include specifying a foreign table.

  ## Examples
      iex> PostgREST.or(filter_builder, ["age < 18", "status = 'inactive'"])

  ## See also
  - Further details on logical operations in Supabase: https://supabase.com/docs/reference/javascript/using-filters#logical-operators
  """
  @impl true
  def unquote(:or)(%FilterBuilder{} = f, columns, opts \\ []) do
    columns = Enum.join(columns, ",")

    if foreign = Keyword.get(opts, :foreign_table) do
      FilterBuilder.add_param(f, "#{foreign}.or", "(#{columns})")
    else
      FilterBuilder.add_param(f, "or", "(#{columns})")
    end
  end

  @doc """
  Applies a "NOT" condition to the query, negating a specified condition.

  ## Parameters
  - `filter_builder`: The FilterBuilder instance.
  - `column`: The column to apply the negation.
  - `op`: The operator used in the condition (e.g., "eq", "gt").
  - `value`: The value to compare against.

  ## Examples
      iex> PostgREST.not(filter_builder, "status", "eq", "active")

  ## See also
  - Supabase negation filters: https://supabase.com/docs/reference/javascript/using-filters#negation
  """
  @impl true
  def unquote(:not)(%FilterBuilder{} = f, column, op, value) do
    FilterBuilder.add_param(f, column, "not.#{op}.#{value}")
  end

  @doc """
  Orders the results of the query by a specified column. You can specify ascending or descending order,
  and handle nulls first or last.

  ## Parameters
  - `filter_builder`: The FilterBuilder instance.
  - `column`: The column by which to order the results.
  - `opts`: Options such as direction (`:asc` or `:desc`) and null handling (`:null_first` or `:null_last`).

  ## Examples
  iex> PostgREST.order(filter_builder, "created_at", asc: true, null_first: false)

  ## See also
  - Supabase ordering results: https://supabase.com/docs/reference/javascript/using-filters#order
  """
  @impl true
  def match(%FilterBuilder{} = f, %{} = query) do
    for {k, v} <- Map.to_list(query), reduce: f do
      f -> FilterBuilder.add_param(f, k, "eq.#{v}")
    end
  end

  @doc """
  Adds an equality filter to the query, specifying that the column must equal a certain value.

  ## Parameters
  - `filter_builder`: The FilterBuilder instance.
  - `column`: The column to apply the filter.
  - `value`: The value the column must equal.

  ## Examples
      iex> PostgREST.eq(filter_builder, "id", 123)

  ## See also
  - Supabase equality filters: https://supabase.com/docs/reference/javascript/using-filters#equality
  """
  @impl true
  def eq(%FilterBuilder{} = f, column, value) do
    FilterBuilder.add_param(f, column, "eq.#{value}")
  end

  @doc """
  Adds a 'not equal' filter to the query, specifying that the column's value must not equal the specified value.

  ## Parameters
  - `filter_builder`: The FilterBuilder instance.
  - `column`: The column to apply the filter.
  - `value`: The value that the column must not equal.

  ## Examples
      iex> PostgREST.neq(filter_builder, "status", "inactive")

  ## See also
  - Supabase not equal filter: https://supabase.com/docs/reference/javascript/using-filters#not-equal
  """
  @impl true
  def neq(%FilterBuilder{} = f, column, value) do
    FilterBuilder.add_param(f, column, "neq.#{value}")
  end

  @doc """
  Adds a 'greater than' filter to the query, specifying that the column's value must be greater than the specified value.

  ## Parameters
  - `filter_builder`: The FilterBuilder instance.
  - `column`: The column to apply the filter.
  - `value`: The value that the column must be greater than.

  ## Examples
      iex> PostgREST.gt(filter_builder, "age", 21)

  ## See also
  - Supabase greater than filter: https://supabase.com/docs/reference/javascript/using-filters#greater-than
  """
  @impl true
  def gt(%FilterBuilder{} = f, column, value) do
    FilterBuilder.add_param(f, column, "gt.#{value}")
  end

  @doc """
  Adds a 'greater than or equal to' filter to the query, specifying that the column's value must be greater than or equal to the specified value.

  ## Parameters
  - `filter_builder`: The FilterBuilder instance.
  - `column`: The column to apply the filter.
  - `value`: The value that the column must be greater than or equal to.

  ## Examples
      iex> PostgREST.gte(filter_builder, "age", 21)

  ## See also
  - Supabase greater than or equal filter: https://supabase.com/docs/reference/javascript/using-filters#greater-than-or-equal
  """
  @impl true
  def gte(%FilterBuilder{} = f, column, value) do
    FilterBuilder.add_param(f, column, "gte.#{value}")
  end

  @doc """
  Adds a 'less than' filter to the query, specifying that the column's value must be less than the specified value.

  ## Parameters
  - `filter_builder`: The FilterBuilder instance.
  - `column`: The column to apply the filter.
  - `value`: The value that the column must be less than.

  ## Examples
      iex> PostgREST.lt(filter_builder, "age", 65)

  ## See also
  - Supabase less than filter: https://supabase.com/docs/reference/javascript/using-filters#less-than
  """
  @impl true
  def lt(%FilterBuilder{} = f, column, value) do
    FilterBuilder.add_param(f, column, "lt.#{value}")
  end

  @doc """
  Adds a 'less than or equal to' filter to the query, specifying that the column's value must be less than or equal to the specified value.

  ## Parameters
  - `filter_builder`: The FilterBuilder instance.
  - `column`: The column to apply the filter.
  - `value`: The value that the column must be less than or equal to.

  ## Examples
      iex> PostgREST.lte(filter_builder, "age", 65)

  ## See also
  - Supabase less than or equal filter: https://supabase.com/docs/reference/javascript/using-filters#less-than-or-equal
  """
  @impl true
  def lte(%FilterBuilder{} = f, column, value) do
    FilterBuilder.add_param(f, column, "lte.#{value}")
  end

  @doc """
  Adds a 'like' filter to the query, allowing for simple pattern matching (SQL LIKE).

  ## Parameters
  - `filter_builder`: The FilterBuilder instance.
  - `column`: The column to apply the filter.
  - `value`: The pattern to match against the column's value.

  ## Examples
      iex> PostgREST.like(filter_builder, "name", "%John%")

  ## See also
  - Supabase like filter: https://supabase.com/docs/reference/javascript/using-filters#like
  """
  @impl true
  def like(%FilterBuilder{} = f, column, value) do
    FilterBuilder.add_param(f, column, "like.#{value}")
  end

  @doc """
  Adds an 'ilike' filter to the query, allowing for case-insensitive pattern matching (SQL ILIKE).

  ## Parameters
  - `filter_builder`: The FilterBuilder instance.
  - `column`: The column to apply the filter.
  - `value`: The pattern to match against the column's value, ignoring case.

  ## Examples
      iex> PostgREST.ilike(filter_builder, "name", "%john%")

  ## See also
  - Supabase ilike filter: https://supabase.com/docs/reference/javascript/using-filters#ilike
  """
  @impl true
  def ilike(%FilterBuilder{} = f, column, value) do
    FilterBuilder.add_param(f, column, "ilike.#{value}")
  end

  @doc """
  Adds an 'is' filter to the query, specifically for checking against `null` or boolean values.

  ## Parameters
  - `filter_builder`: The FilterBuilder instance.
  - `column`: The column to apply the filter.
  - `value`: The value to check the column against (typically null or a boolean).

  ## Examples
      iex> PostgREST.is(filter_builder, "name", nil)

  ## See also
  - Supabase is filter: https://supabase.com/docs/reference/javascript/using-filters#is
  """
  @impl true
  def is(%FilterBuilder{} = f, column, value) do
    FilterBuilder.add_param(f, column, "is.#{value}")
  end

  @doc """
  Filters the query by checking if the column's value is within an array of specified values.

  ## Parameters
  - `filter_builder`: The FilterBuilder instance.
  - `column`: The column to filter.
  - `values`: A list of acceptable values for the column.

  ## Examples
      iex> PostgREST.in(filter_builder, "status", ["active", "pending", "closed"])

  ## See also
  - Supabase "IN" filters: https://supabase.com/docs/reference/javascript/using-filters#in
  """
  @impl true
  def unquote(:in)(%FilterBuilder{} = f, column, values)
      when is_list(values) do
    FilterBuilder.add_param(f, column, "in.(#{Enum.join(values, ",")})")
  end

  @doc """
  Adds a 'contains' filter to the query, checking if the column's array or range contains the specified values.

  ## Parameters
  - `filter_builder`: The FilterBuilder instance.
  - `column`: The column to apply the filter.
  - `values`: The array of values the column must contain.

  ## Examples
      iex> PostgREST.contains(filter_builder, "tags", ["urgent", "new"])

  ## See also
  - Supabase contains filter: https://supabase.com/docs/reference/javascript/using-filters#contains
  """
  @impl true
  def contains(%FilterBuilder{} = f, column, values)
      when is_list(values) do
    FilterBuilder.add_param(f, column, "cs.(#{Enum.join(values, ",")})")
  end

  @doc """
  Adds a 'contained by' filter to the query, checking if the column's array or range is contained by the specified values.

  ## Parameters
  - `filter_builder`: The FilterBuilder instance.
  - `column`: The column to apply the filter.
  - `values`: The array of values that must contain the column's value.

  ## Examples
      iex> PostgREST.contained_by(filter_builder, "tags", ["urgent", "new", "old"])

  ## See also
  - Supabase contained by filter: https://supabase.com/docs/reference/javascript/using-filters#contained-by
  """
  @impl true
  def contained_by(%FilterBuilder{} = f, column, values)
      when is_list(values) do
    FilterBuilder.add_param(f, column, "cd.(#{Enum.join(values, ",")})")
  end

  @doc """
  Adds a 'contains' filter for JSONB columns, checking if the column's JSONB value contains the specified JSON keys and values.

  ## Parameters
  - `filter_builder`: The FilterBuilder instance.
  - `column`: The column to apply the filter.
  - `data`: The JSON object that must be contained within the column's value.

  ## Examples
      iex> PostgREST.contains_object(filter_builder, "metadata", %{type: "info"})

  ## See also
  - Supabase JSON contains filter: https://supabase.com/docs/reference/javascript/using-filters#json-contains
  """
  @impl true
  def contains_object(%FilterBuilder{} = f, column, %{} = data) do
    case Jason.encode(data) do
      {:ok, data} -> FilterBuilder.add_param(f, column, "cs.#{data}")
      _ -> f
    end
  end

  @doc """
  Adds a 'contained by' filter for JSONB columns, checking if the column's JSONB value is contained by the specified JSON keys and values.

  ## Parameters
  - `filter_builder`: The FilterBuilder instance.
  - `column`: The column to apply the filter.
  - `data`: The JSON object that must contain the column's value.

  ## Examples
      iex> PostgREST.contained_by_object(filter_builder, "metadata", %{type: "info"})

  ## See also
  - Supabase JSON contained by filter: https://supabase.com/docs/reference/javascript/using-filters#json-contained-by
  """
  @impl true
  def contained_by_object(%FilterBuilder{} = f, column, %{} = data) do
    case Jason.encode(data) do
      {:ok, data} -> FilterBuilder.add_param(f, column, "cd.#{data}")
      _ -> f
    end
  end

  @doc """
  Filters the query by specifying that the value of a column must be less than a certain point in a range.

  ## Parameters
  - `filter_builder`: The FilterBuilder instance.
  - `column`: The column to apply the filter.
  - `value`: The upper bound value of the range.

  ## Examples
      iex> PostgREST.range_lt(filter_builder, "age", 30)

  ## See also
  - Supabase range filters: https://supabase.com/docs/reference/javascript/using-filters#range
  """
  @impl true
  def range_lt(%FilterBuilder{} = f, column, value) do
    FilterBuilder.add_param(f, column, "sl.#{value}")
  end

  @doc """
  Filters the query by specifying that the value of a column must be greater than a certain point in a range.

  ## Parameters
  - `filter_builder`: The FilterBuilder instance.
  - `column`: The column to apply the filter.
  - `value`: The lower bound value of the range.

  ## Examples
      iex> PostgREST.range_gt(filter_builder, "age", 20)

  ## See also
  - More on range filters at Supabase: https://supabase.com/docs/reference/javascript/using-filters#range
  """
  @impl true
  def range_gt(%FilterBuilder{} = f, column, value) do
    FilterBuilder.add_param(f, column, "sr.#{value}")
  end

  @doc """
  Filters the query by specifying that the value of a column must be greater than or equal to a certain point in a range.

  ## Parameters
  - `filter_builder`: The FilterBuilder instance.
  - `column`: The column to apply the filter.
  - `value`: The starting value of the range.

  ## Examples
      iex> PostgREST.range_gte(filter_builder, "age", 18)

  ## See also
  - Supabase documentation on range filters: https://supabase.com/docs/reference/javascript/using-filters#range
  """
  @impl true
  def range_gte(%FilterBuilder{} = f, column, value) do
    FilterBuilder.add_param(f, column, "nxl.#{value}")
  end

  @doc """
  Filters the query by specifying that the value of a column must be less than or equal to a certain point in a range.

  ## Parameters
  - `filter_builder`: The FilterBuilder instance.
  - `column`: The column to apply the filter.
  - `value`: The ending value of the range.

  ## Examples
      iex> PostgREST.range_lte(filter_builder, "age", 65)

  ## See also
  - Supabase guide on using range filters: https://supabase.com/docs/reference/javascript/using-filters#range
  """
  @impl true
  def range_lte(%FilterBuilder{} = f, column, value) do
    FilterBuilder.add_param(f, column, "nxr.#{value}")
  end

  @doc """
  Filters the query by checking if the value of a column is adjacent to a specified range value.

  ## Parameters
  - `filter_builder`: The FilterBuilder instance.
  - `column`: The column to apply the filter.
  - `value`: The adjacent range value.

  ## Examples
      iex> PostgREST.range_adjacent(filter_builder, "scheduled_time", "2021-01-01T10:00:00Z/2021-01-01T12:00:00Z")

  ## See also
  - Supabase adjacent range filters: https://supabase.com/docs/reference/javascript/using-filters#adjacent
  """
  @impl true
  def range_adjacent(%FilterBuilder{} = f, column, value) do
    FilterBuilder.add_param(f, column, "adj.#{value}")
  end

  @doc """
  Adds an 'overlaps' filter to the query, checking if the column's array overlaps with the specified values.

  ## Parameters
  - `filter_builder`: The FilterBuilder instance.
  - `column`: The column to apply the filter.
  - `values`: The array of values that must overlap with the column's value.

  ## Examples
      iex> PostgREST.overlaps(filter_builder, "tags", ["urgent", "old"])

  ## See also
  - Supabase overlaps filter: https://supabase.com/docs/reference/javascript/using-filters#overlaps
  """
  @impl true
  def overlaps(%FilterBuilder{} = f, column, values)
      when is_list(values) do
    values
    |> Enum.map_join(",", &"%##{&1}")
    |> then(&FilterBuilder.add_param(f, column, "{#{&1}}"))
  end

  @doc """
  Performs a full-text search on a text column in the database, using different search configurations.

  ## Parameters
  - `filter_builder`: The FilterBuilder instance.
  - `column`: The column to search.
  - `query`: The text query for the search.
  - `opts`: Options for the search, such as type of search (`:plain`, `:phrase`, or `:websearch`) and configuration.

  ## Examples
      iex> PostgREST.text_search(filter_builder, "description", "elixir supabase", type: :plain)

  ## See also
  - Supabase full-text search capabilities: https://supabase.com/docs/reference/javascript/using-filters#full-text-search
  """
  @impl true
  def text_search(%FilterBuilder{} = f, column, query, opts \\ []) do
    type = search_type_to_code(Keyword.get(opts, :type))
    config = if config = Keyword.get(opts, :config), do: "(#{config})", else: ""

    FilterBuilder.add_param(f, column, "#{type}fts#{config}.#{query}")
  end

  defp search_type_to_code(:plain), do: "pl"
  defp search_type_to_code(:phrase), do: "ph"
  defp search_type_to_code(:websearch), do: "w"
  defp search_type_to_code(nil), do: nil

  @doc """
  Limits the number of results returned by the query, optionally scoping this limit to a specific foreign table.

  ## Parameters
  - `filter_builder`: The FilterBuilder instance.
  - `count`: The maximum number of results to return.
  - `opts`: Optional parameters, which may include a foreign table.

  ## Examples
      iex> PostgREST.limit(filter_builder, 10)

  ## See also
  - Supabase query limits: https://supabase.com/docs/reference/javascript/using-filters#limit
  """
  @impl true
  def limit(%FilterBuilder{} = f, count, opts \\ []) do
    if foreign = Keyword.get(opts, :foreign_table) do
      FilterBuilder.add_param(f, "#{foreign}.limit", to_string(count))
    else
      FilterBuilder.add_param(f, "limit", to_string(count))
    end
  end

  @doc """
  Orders the results of the query by a specified column. You can specify ascending or descending order,
  and handle nulls first or last.

  ## Parameters
  - `filter_builder`: The FilterBuilder instance.
  - `column`: The column by which to order the results.
  - `opts`: Options such as direction (`:asc` or `:desc`) and null handling (`:null_first` or `:null_last`).

  ## Examples
      iex> PostgREST.order(filter_builder, "created_at", asc: true, null_first: false)

  ## See also
  - Supabase ordering results: https://supabase.com/docs/reference/javascript/using-filters#order
  """
  @impl true
  def order(%FilterBuilder{} = f, column, opts \\ []) do
    order = if opts[:asc], do: "asc", else: "desc"
    nulls_first = if opts[:null_first], do: "nullsfirst", else: "nullslast"
    foreign = Keyword.get(opts, :foreign_table)
    key = if foreign, do: "#{foreign}.order", else: "order"

    if curr = f.params[key] do
      FilterBuilder.add_param(f, key, "#{curr},#{column}.#{order}.#{nulls_first}")
    else
      FilterBuilder.add_param(f, key, "#{column}.#{order}.#{nulls_first}")
    end
  end

  @doc """
  Configures the query to limit results to a specific range based on offset and limit.

  ## Parameters
  - `filter_builder`: The FilterBuilder instance.
  - `from`: The starting index for the results.
  - `to`: The ending index for the results, inclusive.

  ## Examples
      iex> PostgREST.range(filter_builder, 0, 10)

  ## See also
  - Supabase range queries: https://supabase.com/docs/reference/javascript/using-filters#range
  """
  @impl true
  def range(%FilterBuilder{} = f, from, to, opts \\ []) do
    if foreign = Keyword.get(opts, :foreign_table) do
      f
      |> FilterBuilder.add_param("#{foreign}.offset", to_string(from))
      |> FilterBuilder.add_param("#{foreign}.limit", to_string(to - from + 1))
    else
      f
      |> FilterBuilder.add_param("offset", to_string(from))
      |> FilterBuilder.add_param("limit", to_string(to - from + 1))
    end
  end

  @doc """
  Configures the query to expect and return only a single record as a result.
  This modifies the header to indicate that only one object should be returned.

  ## Parameters
  - `filter_builder`: The FilterBuilder instance to modify.

  ## Examples
      iex> PostgREST.single(filter_builder)

  ## See also
  - Supabase single row mode: https://supabase.com/docs/reference/javascript/using-filters#single-row
  """
  @impl true
  def single(%FilterBuilder{} = f) do
    FilterBuilder.add_header(f, "accept", "application/vnd.pgrst.object+json")
  end

  @doc """
  Executes the query built using the QueryBuilder or FilterBuilder instance and returns the raw result.

  ## Parameters
  - `filter_builder`: The FilterBuilder or QueryBuilder instance to execute.

  ## Examples
      iex> PostgREST.execute(filter_builder)

  ## See also
  - Supabase query execution: https://supabase.com/docs/reference/javascript/performing-queries
  """
  @impl true
  def execute(%FilterBuilder{} = f) do
    execute(f.client, f.method, f.body, f.table, f.headers, f.params)
  end

  def execute(%QueryBuilder{} = q) do
    execute(q.client, q.method, q.body, q.table, q.headers, q.params)
  end

  @doc """
  Executes the query and returns the result as a JSON-encoded string.

  ## Parameters
  - `filter_builder`: The FilterBuilder or QueryBuilder instance to execute.

  ## Examples
      iex> PostgREST.execute_string(filter_builder)

  ## See also
  - Supabase query execution and response handling: https://supabase.com/docs/reference/javascript/performing-queries
  """
  @impl true
  def execute_string(%FilterBuilder{} = f) do
    with {:ok, body} <- execute(f.client, f.method, f.body, f.table, f.headers, f.params) do
      Jason.encode(body)
    end
  end

  def execute_string(%QueryBuilder{} = q) do
    with {:ok, body} <- execute(q.client, q.method, q.body, q.table, q.headers, q.params) do
      Jason.encode(body)
    end
  end

  @doc """
  Executes the query and maps the resulting data to a specified schema struct, useful for casting the results to Elixir structs.

  ## Parameters
  - `filter_builder`: The FilterBuilder or QueryBuilder instance to execute.
  - `schema`: The Elixir module representing the schema to which the results should be cast.

  ## Examples
      iex> PostgREST.execute_to(filter_builder, User)

  ## See also
  - Supabase query execution and schema casting: https://supabase.com/docs/reference/javascript/performing-queries
  """
  @impl true
  def execute_to(%FilterBuilder{} = f, schema) when is_atom(schema) do
    with {:ok, body} <- execute(f.client, f.method, f.body, f.table, f.headers, f.params) do
      if is_list(body) do
        {:ok, Enum.map(body, &struct(schema, &1))}
      else
        {:ok, struct(schema, body)}
      end
    end
  end

  def execute_to(%QueryBuilder{} = q, schema) when is_atom(schema) do
    with {:ok, body} <- execute(q.client, q.method, q.body, q.table, q.headers, q.params) do
      if is_list(body) do
        {:ok, Enum.map(body, &struct(schema, &1))}
      else
        {:ok, struct(schema, body)}
      end
    end
  end

  @api_path "rest/v1"

  @doc """
  Executes a query using the Finch HTTP client, formatting the request appropriately.

  ## Parameters
  - `filter_builder`: The FilterBuilder or QueryBuilder instance to execute.
  - `schema`: Optional schema module to map the results.

  ## Examples
      iex> PostgREST.execute_to_finch_request(filter_builder, User)

  ## See also
  - Supabase query execution: https://supabase.com/docs/reference/javascript/performing-queries
  """
  @impl true
  def execute_to_finch_request(%mod{client: client} = q)
      when Kernel.in(mod, [FilterBuilder, QueryBuilder]) do
    base_url = Path.join([client.conn.base_url, @api_path, q.table])
    headers = apply_headers(client, q.headers)
    query = URI.encode_query(q.params)
    url = URI.new!(base_url) |> URI.append_query(query)

    Supabase.Fetcher.new_connection(q.method, url, q.body, headers)
  end

  defp execute(client, method, body, table, headers, params) do
    base_url = Path.join([client.conn.base_url, @api_path, table])
    headers = apply_headers(client, headers)
    query = URI.encode_query(params)
    url = URI.new!(base_url) |> URI.append_query(query)
    request = request_fun_from_method(method)

    url
    |> request.(body, headers)
    |> parse_response()
  end

  defp apply_headers(client, headers) do
    accept_profile = {"accept-profile", client.db.schema}
    content_profile = {"content-profile", client.db.schema}
    content_type = {"content-type", "application/json"}
    additional_headers = Map.to_list(headers) ++ [accept_profile, content_profile, content_type]

    Supabase.Fetcher.apply_client_headers(client, nil, additional_headers)
  end

  defp request_fun_from_method(:get), do: &Supabase.Fetcher.get/3
  defp request_fun_from_method(:head), do: &Supabase.Fetcher.head/3
  defp request_fun_from_method(:post), do: &Supabase.Fetcher.post/3
  defp request_fun_from_method(:delete), do: &Supabase.Fetcher.delete/3
  defp request_fun_from_method(:patch), do: &Supabase.Fetcher.patch/3

  defp parse_response({:error, reason}), do: {:error, reason}

  defp parse_response({:ok, %{status: status, body: raw}}) do
    with {:ok, body} <- Jason.decode(raw, keys: :atoms) do
      cond do
        error_resp?(status) -> {:error, Error.from_raw_body(body)}
        success_resp?(status) -> {:ok, body}
      end
    end
  end

  defp error_resp?(status) do
    Kernel.in(status, 400..599)
  end

  defp success_resp?(status) do
    Kernel.in(status, 200..399)
  end
end
