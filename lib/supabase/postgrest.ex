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
  alias Supabase.Fetcher
  alias Supabase.PostgREST.Builder
  alias Supabase.PostgREST.Error

  @behaviour Supabase.PostgRESTBehaviour

  @accept_headers %{
    default: "*/*",
    csv: "text/csv",
    json: "application/json",
    openapi: "application/openapi+json",
    postgis: "application/geo+json",
    pgrst_plan: "application/vnd.pgrst.plan+json",
    pgrst_object: "application/vnd.pgrst.object+json",
    pgrst_array: "application/vnd.pgrst.array+json"
  }

  @doc """
  Initializes a `Builder` for a specified table and client.

  ## Parameters
  - `client`: The Supabase client used for authentication and configuration.
  - `table`: The database relation name as a string.

  ## Examples
      iex> PostgREST.from(client, "users")
      %Builder{}

  ## See also
  - Supabase documentation on initializing queries: https://supabase.com/docs/reference/javascript/from
  """
  @impl true
  def from(%Client{} = client, table) do
    client
    |> Builder.new(relation: table)
    |> with_custom_media_type(:default)
  end

  @doc """
  Select a schema to query or perform an function (rpc) call.
  The schema needs to be on the list of exposed schemas inside Supabase.

  ## Parameters
  - `schema`: the schema to operate on, default to the `Supabase.Client` DB config

  ## Examples
      iex> builder = Supabase.PostgREST.from(client, "users")
      iex> Supabase.PostgREST.schema(builder, private)
  """
  @impl true
  def schema(%Builder{} = b, schema) when is_binary(schema) do
    %{b | schema: schema}
  end

  @doc """
  Overrides the default media type `accept` header, which can control
  the represation of the PostgREST response

  ## Examples
      iex> q = PostgREST.from(client, "users")
      iex> q = PostgREST.with_custom_media_type(q, :csv)
      iex> PostgREST.execute(q)
      {:ok, "id,name\n1,john\n2,maria"}

  ## See also
  - [PostgREST resource represation docs](https://docs.postgrest.org/en/v12/references/api/resource_representation.html)
  """
  @impl true
  def with_custom_media_type(%Builder{} = b, media_type)
      when is_atom(media_type) do
    header = @accept_headers[media_type] || @accept_headers[:default]
    Builder.add_request_header(b, "accept", header)
  end

  @doc """
  Selects records from a table. You can specify specific columns or use '*' for all columns.
  Options such as counting results and specifying return types can be configured.

  Note that this function does not return by default, it only build the select
  expression for the query. If you want to have the selected fields returned as
  response you need to pass `returning: true`.

  ## Parameters
  - `builder`: The Builder instance.
  - `columns`: A list of column names to fetch or '*' for all columns.
  - `opts`: Options such as `:count` and `:returning`.

  ## Examples
      iex> PostgREST.select(builder, "*", count: :exact, returning: true)

  ## See also
  - Supabase select queries: https://supabase.com/docs/reference/javascript/select
  """
  @impl true
  def select(builder, columns, opts \\ [])

  def select(%Builder{} = b, "*", opts) do
    do_select(b, "*", opts)
  end

  def select(%Builder{} = b, columns, opts)
      when is_list(columns) do
    do_select(b, Enum.join(columns, ","), opts)
  end

  @spec do_select(Builder.t(), String.t(), keyword) :: Builder.t()
  defp do_select(%Builder{} = b, columns, opts) do
    count = Keyword.get(opts, :count, :exact)
    returning = Keyword.get(opts, :returning, false)

    b
    |> Builder.change_method(:get)
    |> Builder.add_query_param("select", columns)
    |> Builder.add_request_header("prefer", "count=#{count}")
    |> then(fn builder ->
      if returning do
        Builder.change_method(builder, :get)
      else
        Builder.change_method(builder, :head)
      end
    end)
  end

  @doc """
  Inserts new records into the database. Supports conflict resolution and specifying how the
  result should be returned.

  ## Parameters
  - `builder`: The Builder to use.
  - `data`: The data to be inserted, typically a map or a list of maps.
  - `opts`: Options like `:on_conflict`, `:returning`, and `:count`.

  ## Examples
      iex> PostgREST.insert(builder, %{name: "John"}, on_conflict: "name", returning: :minimal)

  ## See also
  - Supabase documentation on inserts: https://supabase.com/docs/reference/javascript/insert
  """
  @impl true
  def insert(%Builder{} = b, data, opts \\ []) when is_map(data) do
    on_conflict = Keyword.get(opts, :on_conflict)
    on_conflict = if on_conflict, do: "on_conflict=#{on_conflict}"
    upsert = if on_conflict, do: "resolution=merge-duplicates"
    returning = Keyword.get(opts, :returning, :representation)
    count = Keyword.get(opts, :count, :exact)
    prefer = ["return=#{returning}", "count=#{count}", on_conflict, upsert]
    prefer = Enum.join(Enum.reject(prefer, &is_nil/1), ",")

    b
    |> Builder.change_method(:post)
    |> Builder.add_request_header("prefer", prefer)
    |> Builder.add_query_param("on_conflict", on_conflict)
    |> Builder.change_body(data)
  end

  @doc """
  Upserts data into a table, allowing for conflict resolution and specifying return options.

  ## Parameters
  - `builder`: The Builder to use.
  - `data`: The data to upsert, typically a map or a list of maps.
  - `opts`: Options like `:on_conflict`, `:returning`, and `:count`.

  ## Examples
      iex> PostgREST.upsert(builder, %{name: "Jane"}, on_conflict: "name", returning: :representation)

  ## See also
  - Supabase documentation on upserts: https://supabase.com/docs/reference/javascript/upsert
  """
  @impl true
  def upsert(%Builder{} = b, data, opts \\ []) when is_map(data) do
    on_conflict = Keyword.get(opts, :on_conflict)
    returning = Keyword.get(opts, :returning, :representation)
    count = Keyword.get(opts, :count, :exact)

    prefer =
      Enum.join(["resolution=merge-duplicates", "return=#{returning}", "count=#{count}"], ",")

    b
    |> Builder.change_method(:post)
    |> Builder.add_request_header("prefer", prefer)
    |> Builder.add_query_param("on_conflict", on_conflict)
    |> Builder.change_body(data)
  end

  @doc """
  Deletes records from a table based on the conditions specified in the Builder.

  ## Parameters
  - `builder`: The Builder to use.
  - `opts`: Options such as `:returning` and `:count`.

  ## Examples
      iex> PostgREST.delete(builder, returning: :representation)

  ## See also
  - Supabase documentation on deletes: https://supabase.com/docs/reference/javascript/delete
  """
  @impl true
  def delete(%Builder{} = b, opts \\ []) do
    returning = Keyword.get(opts, :returning, :representation)
    count = Keyword.get(opts, :count, :exact)
    prefer = Enum.join(["return=#{returning}", "count=#{count}"], ",")

    b
    |> Builder.change_method(:delete)
    |> Builder.add_request_header("prefer", prefer)
  end

  @doc """
  Updates existing records in the database. Allows specifying return options and how the update is counted.

  ## Parameters
  - `builder`: The Builder to use.
  - `data`: The new data for the update, typically a map or list of maps.
  - `opts`: Options such as `:returning` and `:count`.

  ## Examples
      iex> PostgREST.update(builder, %{name: "Doe"}, returning: :representation)

  ## See also
  - Supabase documentation on updates: https://supabase.com/docs/reference/javascript/update
  """
  @impl true
  def update(%Builder{} = b, data, opts \\ []) when is_map(data) do
    returning = Keyword.get(opts, :returning, :representation)
    count = Keyword.get(opts, :count, :exact)
    prefer = Enum.join(["return=#{returning}", "count=#{count}"], ",")

    b
    |> Builder.change_method(:patch)
    |> Builder.add_request_header("prefer", prefer)
    |> Builder.change_body(data)
  end

  @doc """
  Match only rows which satisfy the filter. This is an escape hatch - you
  hould use the specific filter methods wherever possible.

  Unlike most filters, `opearator` and `value` are used as-is and need to
  follow [PostgREST syntax](https://postgrest.org/en/stable/api.html#operators). You also need to make sure they are properly sanitized.

  ## Parameters
  - `column` - The column to filter on
  - `operator` - The operator to filter with, following PostgREST syntax
  - `value` - The value to filter with, following PostgREST syntax

  ## Examples
      iex> PostgREST.filter(builder, "id", "not", 12)
  """
  @impl true
  def filter(%Builder{} = b, column, op, value) do
    Builder.add_query_param(b, column, "#{op}.#{value}")
  end

  @doc """
  Applies an "AND" condition to a query, allowing multiple conditions on different columns.
  This can also be scoped to a foreign table if specified.

  Unlike most filters, `filters` is used as-is and needs to follow [PostgREST syntax](https://postgrest.org/en/stable/api.html#operators). You also need to make sure it's properly sanitized.

  It's currently not possible to do an `.and()` filter across multiple tables.

  ## Parameters
  - `builder`: The Builder instance.
  - `columns`: A list of conditions that should all be met.
  - `opts`: Optional parameters, which can include specifying a foreign table.

  ## Examples
      iex> PostgREST.and(builder, ["age > 18", "status = 'active'"])

  ## See also
  - Supabase logical operations: https://supabase.com/docs/reference/javascript/using-filters#logical-operators
  """
  @impl true
  def unquote(:and)(%Builder{} = b, columns, opts \\ []) do
    columns = Enum.join(columns, ",")

    if foreign = Keyword.get(opts, :foreign_table) do
      Builder.add_query_param(b, "#{foreign}.and", "(#{columns})")
    else
      Builder.add_query_param(b, "and", "(#{columns})")
    end
  end

  @doc """
  Applies an "OR" condition to a query, combining multiple conditions on different columns
  where at least one condition must be met. This can also be scoped to a foreign table.

  Unlike most filters, `filters` is used as-is and needs to follow [PostgREST syntax](https://postgrest.org/en/stable/api.html#operators). You also need to make sure it's properly sanitized.

  It's currently not possible to do an `.and()` filter across multiple tables.

  ## Parameters
  - `builder`: The Builder instance.
  - `columns`: A list of conditions where at least one should be met.
  - `opts`: Optional parameters, which can include specifying a foreign table.

  ## Examples
      iex> PostgREST.or(builder, ["age < 18", "status = 'inactive'"])

  ## See also
  - Further details on logical operations in Supabase: https://supabase.com/docs/reference/javascript/using-filters#logical-operators
  """
  @impl true
  def unquote(:or)(%Builder{} = b, columns, opts \\ []) do
    columns = Enum.join(columns, ",")

    if foreign = Keyword.get(opts, :foreign_table) do
      Builder.add_query_param(b, "#{foreign}.or", "(#{columns})")
    else
      Builder.add_query_param(b, "or", "(#{columns})")
    end
  end

  @doc """
  Applies a "NOT" condition to the query, negating a specified condition.

  Unlike most filters, `opearator` and `value` are used as-is and need to
  follow [PostgREST syntax](https://postgrest.org/en/stable/api.html#operators). You also need
  to make sure they are properly sanitized.

  ## Parameters
  - `builder`: The Builder instance.
  - `column`: The column to apply the negation.
  - `op`: The operator used in the condition (e.g., "eq", "gt").
  - `value`: The value to compare against.

  ## Examples
      iex> PostgREST.not(builder, "status", "eq", "active")

  ## See also
  - Supabase negation filters: https://supabase.com/docs/reference/javascript/using-filters#negation
  """
  @impl true
  def unquote(:not)(%Builder{} = b, column, op, value) do
    Builder.add_query_param(b, column, "not.#{op}.#{value}")
  end

  @doc """
  Match only rows where each column in `query` keys is equal to its associated value. Shorthand for multiple `.eq()`s.

  ## Parameters
  - `query` - The object to filter with, with column names as keys mapped to their filter values

  ## Examples
  iex> PostgREST.match(builder, %{"col1" => true, "col2" => false})

  ## See also
  - Supabase ordering results: https://supabase.com/docs/reference/javascript/using-filters#match
  """
  @impl true
  def match(%Builder{} = b, %{} = query) do
    for {k, v} <- Map.to_list(query), reduce: b do
      b -> Builder.add_query_param(b, k, "eq.#{v}")
    end
  end

  @doc """
  Adds an equality filter to the query, specifying that the column must equal a certain value.

  To check if the value of `column` is `NULL`, you should use `.is()` instead.

  ## Parameters
  - `builder`: The Builder instance.
  - `column`: The column to apply the filter.
  - `value`: The value the column must equal.

  ## Examples
      iex> PostgREST.eq(builder, "id", 123)

  ## See also
  - Supabase equality filters: https://supabase.com/docs/reference/javascript/using-filters#equality
  """
  @impl true
  def eq(%Builder{} = f, column, value) do
    Builder.add_query_param(f, column, "eq.#{value}")
  end

  @doc """
  Adds a 'not equal' filter to the query, specifying that the column's value must not equal the specified value.

  ## Parameters
  - `builder`: The Builder instance.
  - `column`: The column to apply the filter.
  - `value`: The value that the column must not equal.

  ## Examples
      iex> PostgREST.neq(builder, "status", "inactive")

  ## See also
  - Supabase not equal filter: https://supabase.com/docs/reference/javascript/using-filters#not-equal
  """
  @impl true
  def neq(%Builder{} = f, column, value) do
    Builder.add_query_param(f, column, "neq.#{value}")
  end

  @doc """
  Adds a 'greater than' filter to the query, specifying that the column's value must be greater than the specified value.

  ## Parameters
  - `builder`: The Builder instance.
  - `column`: The column to apply the filter.
  - `value`: The value that the column must be greater than.

  ## Examples
      iex> PostgREST.gt(builder, "age", 21)

  ## See also
  - Supabase greater than filter: https://supabase.com/docs/reference/javascript/using-filters#greater-than
  """
  @impl true
  def gt(%Builder{} = f, column, value) do
    Builder.add_query_param(f, column, "gt.#{value}")
  end

  @doc """
  Adds a 'greater than or equal to' filter to the query, specifying that the column's value must be greater than or equal to the specified value.

  ## Parameters
  - `builder`: The Builder instance.
  - `column`: The column to apply the filter.
  - `value`: The value that the column must be greater than or equal to.

  ## Examples
      iex> PostgREST.gte(builder, "age", 21)

  ## See also
  - Supabase greater than or equal filter: https://supabase.com/docs/reference/javascript/using-filters#greater-than-or-equal
  """
  @impl true
  def gte(%Builder{} = f, column, value) do
    Builder.add_query_param(f, column, "gte.#{value}")
  end

  @doc """
  Adds a 'less than' filter to the query, specifying that the column's value must be less than the specified value.

  ## Parameters
  - `builder`: The Builder instance.
  - `column`: The column to apply the filter.
  - `value`: The value that the column must be less than.

  ## Examples
      iex> PostgREST.lt(builder, "age", 65)

  ## See also
  - Supabase less than filter: https://supabase.com/docs/reference/javascript/using-filters#less-than
  """
  @impl true
  def lt(%Builder{} = f, column, value) do
    Builder.add_query_param(f, column, "lt.#{value}")
  end

  @doc """
  Adds a 'less than or equal to' filter to the query, specifying that the column's value must be less than or equal to the specified value.

  ## Parameters
  - `builder`: The Builder instance.
  - `column`: The column to apply the filter.
  - `value`: The value that the column must be less than or equal to.

  ## Examples
      iex> PostgREST.lte(builder, "age", 65)

  ## See also
  - Supabase less than or equal filter: https://supabase.com/docs/reference/javascript/using-filters#less-than-or-equal
  """
  @impl true
  def lte(%Builder{} = f, column, value) do
    Builder.add_query_param(f, column, "lte.#{value}")
  end

  @doc """
  Adds a 'like' filter to the query, allowing for simple pattern matching (SQL LIKE).

  ## Parameters
  - `builder`: The Builder instance.
  - `column`: The column to apply the filter.
  - `value`: The pattern to match against the column's value.

  ## Examples
      iex> PostgREST.like(builder, "name", "%John%")

  ## See also
  - Supabase like filter: https://supabase.com/docs/reference/javascript/using-filters#like
  """
  @impl true
  def like(%Builder{} = f, column, value) do
    Builder.add_query_param(f, column, "like.#{value}")
  end

  @doc """
  Adds an 'ilike' filter to the query, allowing for case-insensitive pattern matching (SQL ILIKE).

  ## Parameters
  - `builder`: The Builder instance.
  - `column`: The column to apply the filter.
  - `value`: The pattern to match against the column's value, ignoring case.

  ## Examples
      iex> PostgREST.ilike(builder, "name", "%john%")

  ## See also
  - Supabase ilike filter: https://supabase.com/docs/reference/javascript/using-filters#ilike
  """
  @impl true
  def ilike(%Builder{} = f, column, value) do
    Builder.add_query_param(f, column, "ilike.#{value}")
  end

  @doc """
  Match only rows where `column` IS `value`.

  For non-boolean columns, this is only relevant for checking if the value of
  `column` is NULL by setting `value` to `null`.

  For boolean columns, you can also set `value` to `true` or `false` and it
  will behave the same way as `.eq()`.

  ## Parameters
  - `builder`: The Builder instance.
  - `column`: The column to apply the filter.
  - `value`: The value to check the column against (typically null or a boolean).

  ## Examples
      iex> PostgREST.is(builder, "name", nil)

  ## See also
  - Supabase is filter: https://supabase.com/docs/reference/javascript/using-filters#is
  """
  @impl true
  def is(%Builder{} = f, column, value) do
    Builder.add_query_param(f, column, "is.#{value}")
  end

  @doc """
  Filters the query by checking if the column's value is within an array of specified values.

  ## Parameters
  - `builder`: The Builder instance.
  - `column`: The column to filter.
  - `values`: A list of acceptable values for the column.

  ## Examples
      iex> PostgREST.in(builder, "status", ["active", "pending", "closed"])

  ## See also
  - Supabase "IN" filters: https://supabase.com/docs/reference/javascript/using-filters#in
  """
  @impl true
  def unquote(:in)(%Builder{} = f, column, values)
      when is_list(values) do
    Builder.add_query_param(f, column, "in.(#{Enum.join(values, ",")})")
  end

  @doc """
  Only relevant for jsonb, array, and range columns. Match only rows where `column` contains every element appearing in `value`.

  ## Parameters
  - `builder`: The Builder instance.
  - `column`: The column to apply the filter.
  - `values`: It can be a single value (string), a list of values to filter or a map (aka json)

  ## Examples
      iex> PostgREST.contains(builder, "tags", ["urgent", "new"])

  ## See also
  - Supabase contains filter: https://supabase.com/docs/reference/javascript/using-filters#contains
  """
  @impl true
  def contains(%Builder{} = b, column, value) when is_binary(value) do
    do_contains(b, column, value)
  end

  def contains(%Builder{} = b, column, values) when is_list(values) do
    do_contains(b, column, "{#{Enum.join(values, ",")}}")
  end

  def contains(%Builder{} = b, column, values) when is_map(values) do
    do_contains(b, column, Jason.encode!(values))
  end

  defp do_contains(%Builder{} = b, column, value) do
    Builder.add_query_param(b, column, "cs.#{value}")
  end

  @doc """
  Only relevant for jsonb, array, and range columns. Match only rows where every element appearing in `column` is contained by `value`.

  ## Parameters
  - `builder`: The Builder instance.
  - `column`: The column to apply the filter.
  - `values`: It can be a single value (string), a list of values to filter or a map (aka json)

  ## Examples
      iex> PostgREST.contained_by(builder, "tags", ["urgent", "new", "old"])

  ## See also
  - Supabase contained by filter: https://supabase.com/docs/reference/javascript/using-filters#contained-by
  """
  @impl true
  def contained_by(%Builder{} = b, column, value) when is_binary(value) do
    do_contained_by(b, column, value)
  end

  def contained_by(%Builder{} = b, column, values) when is_list(values) do
    do_contained_by(b, column, "{#{Enum.join(values, ",")}}")
  end

  def contained_by(%Builder{} = b, column, values) when is_map(values) do
    do_contained_by(b, column, Jason.encode!(values))
  end

  defp do_contained_by(%Builder{} = b, column, value) do
    Builder.add_query_param(b, column, "cd.#{value}")
  end

  @doc """
  Only relevant for range columns. Match only rows where every element in `column` is less than any element in `range`.

  ## Parameters
  - `builder`: The Builder instance.
  - `column`: The column to apply the filter.
  - `value`: The upper bound value of the range.

  ## Examples
      iex> PostgREST.range_lt(builder, "age", 30)

  ## See also
  - Supabase range filters: https://supabase.com/docs/reference/javascript/using-filters#range
  """
  @impl true
  def range_lt(%Builder{} = f, column, value) do
    Builder.add_query_param(f, column, "sl.#{value}")
  end

  @doc """
  Only relevant for range columns. Match only rows where every element in `column` is greater than any element in `range`.

  ## Parameters
  - `builder`: The Builder instance.
  - `column`: The column to apply the filter.
  - `value`: The lower bound value of the range.

  ## Examples
      iex> PostgREST.range_gt(builder, "age", 20)

  ## See also
  - More on range filters at Supabase: https://supabase.com/docs/reference/javascript/using-filters#range
  """
  @impl true
  def range_gt(%Builder{} = f, column, value) do
    Builder.add_query_param(f, column, "sr.#{value}")
  end

  @doc """
  Only relevant for range columns. Match only rows where every element in `column` is either contained in `range` or greater than any element in `range`.

  ## Parameters
  - `builder`: The Builder instance.
  - `column`: The column to apply the filter.
  - `value`: The starting value of the range.

  ## Examples
      iex> PostgREST.range_gte(builder, "age", 18)

  ## See also
  - Supabase documentation on range filters: https://supabase.com/docs/reference/javascript/using-filters#range
  """
  @impl true
  def range_gte(%Builder{} = f, column, value) do
    Builder.add_query_param(f, column, "nxl.#{value}")
  end

  @doc """
  Only relevant for range columns. Match only rows where every element in `column` is either contained in `range` or less than any element in `range`.

  ## Parameters
  - `builder`: The Builder instance.
  - `column`: The column to apply the filter.
  - `value`: The ending value of the range.

  ## Examples
      iex> PostgREST.range_lte(builder, "age", 65)

  ## See also
  - Supabase guide on using range filters: https://supabase.com/docs/reference/javascript/using-filters#range
  """
  @impl true
  def range_lte(%Builder{} = f, column, value) do
    Builder.add_query_param(f, column, "nxr.#{value}")
  end

  @doc """
  Only relevant for range columns. Match only rows where `column` is mutually exclusive to `range` and there can be no element between the two ranges.

  ## Parameters
  - `builder`: The Builder instance.
  - `column`: The column to apply the filter.
  - `value`: The adjacent range value.

  ## Examples
      iex> PostgREST.range_adjacent(builder, "scheduled_time", "2021-01-01T10:00:00Z/2021-01-01T12:00:00Z")

  ## See also
  - Supabase adjacent range filters: https://supabase.com/docs/reference/javascript/using-filters#adjacent
  """
  @impl true
  def range_adjacent(%Builder{} = f, column, value) do
    Builder.add_query_param(f, column, "adj.#{value}")
  end

  @doc """
  Only relevant for array and range columns. Match only rows where `column` and `value` have an element in common.

  ## Parameters
  - `builder`: The Builder instance.
  - `column`: The column to apply the filter.
  - `values`: The array of values that must overlap with the column's value.

  ## Examples
      iex> PostgREST.overlaps(builder, "tags", ["urgent", "old"])

  ## See also
  - Supabase overlaps filter: https://supabase.com/docs/reference/javascript/using-filters#overlaps
  """
  @impl true
  def overlaps(%Builder{} = b, column, value) when is_binary(value) do
    Builder.add_query_param(b, column, "ov.#{value}")
  end

  def overlaps(%Builder{} = b, column, values) when is_list(values) do
    values
    |> Enum.join(",")
    |> then(&Builder.add_query_param(b, column, "ov.{#{&1}}"))
  end

  @doc """
  Only relevant for text and tsvector columns. Match only rows where `column` matches the query string in `query`.

  ## Parameters
  - `builder`: The Builder instance.
  - `column`: The column to search.
  - `query`: The text query for the search.
  - `opts`: Options for the search, such as type of search (`:plain`, `:phrase`, or `:websearch`) and configuration.

  ## Examples
      iex> PostgREST.text_search(builder, "description", "elixir supabase", type: :plain)

  ## See also
  - Supabase full-text search capabilities: https://supabase.com/docs/reference/javascript/using-filters#full-text-search
  """
  @impl true
  def text_search(%Builder{} = f, column, query, opts \\ []) do
    type = search_type_to_code(Keyword.get(opts, :type))
    config = if config = Keyword.get(opts, :config), do: "(#{config})", else: ""

    Builder.add_query_param(f, column, "#{type}fts#{config}.#{query}")
  end

  defp search_type_to_code(:plain), do: "pl"
  defp search_type_to_code(:phrase), do: "ph"
  defp search_type_to_code(:websearch), do: "w"
  defp search_type_to_code(nil), do: nil

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
    with_custom_media_type(b, :pgrst_object)
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
    with_custom_media_type(b, :json)
  end

  def maybe_single(%Builder{} = b) do
    with_custom_media_type(b, :pgrst_object)
  end

  @doc """
  Executes the query built using the Builder instance and returns the result.

  ## Parameters
  - `builder`: The Builder or Builder instance to execute.

  ## Examples
      iex> PostgREST.execute(builder)

  ## See also
  - Supabase query execution: https://supabase.com/docs/reference/javascript/performing-queries
  """
  @impl true
  def execute(%Builder{} = b), do: do_execute(b)

  @doc """
  Executes the query and returns the result as a JSON-encoded string.

  ## Parameters
  - `builder`: The Builder or Builder instance to execute.

  ## Examples
      iex> PostgREST.execute_string(builder)

  ## See also
  - Supabase query execution and response handling: https://supabase.com/docs/reference/javascript/performing-queries
  """
  @impl true
  def execute_string(%Builder{} = b) do
    with {:ok, body} <- do_execute(b) do
      Jason.encode(body)
    end
  end

  @doc """
  Executes the query and maps the resulting data to a specified schema struct, useful for casting the results to Elixir structs.

  ## Parameters
  - `builder`: The Builder or Builder instance to execute.
  - `schema`: The Elixir module representing the schema to which the results should be cast.

  ## Examples
      iex> PostgREST.execute_to(builder, User)

  ## See also
  - Supabase query execution and schema casting: https://supabase.com/docs/reference/javascript/performing-queries
  """
  @impl true
  def execute_to(%Builder{} = b, schema) when is_atom(schema) do
    with {:ok, body} <- do_execute(b) do
      if is_list(body) do
        {:ok, Enum.map(body, &struct(schema, &1))}
      else
        {:ok, struct(schema, body)}
      end
    end
  end

  @doc """
  Executes a query using the Finch HTTP client, formatting the request appropriately. Returns the HTTP request without executing it.

  ## Parameters
  - `builder`: The Builder or Builder instance to execute.
  - `schema`: Optional schema module to map the results.

  ## Examples
      iex> PostgREST.execute_to_finch_request(builder, User)

  ## See also
  - Supabase query execution: https://supabase.com/docs/reference/javascript/performing-queries
  """
  @impl true
  def execute_to_finch_request(%Builder{client: client} = b) do
    headers = Fetcher.apply_client_headers(client, nil, Map.to_list(b.headers))
    query = URI.encode_query(b.params)
    url = URI.new!(b.url) |> URI.append_query(query)

    Supabase.Fetcher.new_connection(b.method, url, b.body, headers)
  end

  defp do_execute(%Builder{client: client} = b) do
    headers = Fetcher.apply_client_headers(client, nil, Map.to_list(b.headers))
    query = URI.encode_query(b.params)
    url = URI.new!(b.url) |> URI.append_query(query)
    request = request_fun_from_method(b.method)

    url
    |> request.(b.body, headers)
    |> parse_response()
  end

  defp request_fun_from_method(:get), do: &Supabase.Fetcher.get/3
  defp request_fun_from_method(:head), do: &Supabase.Fetcher.head/3
  defp request_fun_from_method(:post), do: &Supabase.Fetcher.post/3
  defp request_fun_from_method(:delete), do: &Supabase.Fetcher.delete/3
  defp request_fun_from_method(:patch), do: &Supabase.Fetcher.patch/3

  defp parse_response({:error, reason}), do: {:error, reason}

  defp parse_response({:ok, %{status: _, body: ""}}) do
    {:ok, nil}
  end

  defp parse_response({:ok, %{status: status, body: raw, headers: headers}}) do
    if json_content?(headers) do
      with {:ok, body} <- Jason.decode(raw, keys: :atoms) do
        cond do
          error_resp?(status) -> {:error, Error.from_raw_body(body)}
          success_resp?(status) -> {:ok, body}
        end
      end
    else
      {:ok, raw}
    end
  end

  defp json_content?(headers) when is_list(headers) do
    headers
    |> Enum.find_value(fn
      {"content-type", type} -> type
      _ -> false
    end)
    |> String.match?(~r/json/)
  end

  defp error_resp?(status) do
    Kernel.in(status, 400..599)
  end

  defp success_resp?(status) do
    Kernel.in(status, 200..399)
  end
end
