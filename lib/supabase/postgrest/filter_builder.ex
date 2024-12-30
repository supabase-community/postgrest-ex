defmodule Supabase.PostgREST.FilterBuilder do
  @moduledoc """
  Manages filtering logic for queries.

  This module allows you to define conditions that restrict the data returned by the query. Filters can include equality checks, range conditions, pattern matching, and more. These operations translate into query parameters that control the subset of data fetched or manipulated.
  """

  alias Supabase.PostgREST.Builder

  @behaviour Supabase.PostgREST.FilterBuilder.Behaviour

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
end
