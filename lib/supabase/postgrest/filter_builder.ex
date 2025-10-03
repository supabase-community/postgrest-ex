defmodule Supabase.PostgREST.FilterBuilder do
  @moduledoc """
  Manages filtering logic for queries.

  This module allows you to define conditions that restrict the data returned by the query. Filters can include equality checks, range conditions, pattern matching, and more. These operations translate into query parameters that control the subset of data fetched or manipulated.
  """

  alias Supabase.Fetcher.Request

  @behaviour Supabase.PostgREST.FilterBuilder.Behaviour

  @filter_ops [
    :eq,
    :gt,
    :gte,
    :lt,
    :lte,
    :neq,
    :like,
    :ilike,
    :match,
    :imatch,
    :in,
    :is,
    :isdistinct,
    :fts,
    :plfts,
    :phfts,
    :wfts,
    :cs,
    :cd,
    :ov,
    :sl,
    :sr,
    :nxr,
    :nxl,
    :adj,
    :not,
    :and,
    :or,
    :all,
    :any
  ]

  @doc """
  Guard to validates if the filter operator passed to
  `__MODULE__.filter/3` is a valid operator.
  """
  defguard is_filter_op(op) when op in @filter_ops

  @doc """
  Match only rows which satisfy the filter. This is an escape hatch - you
  hould use the specific filter methods wherever possible.

  Unlike most filters, `opearator` and `value` are used as-is and need to
  follow [PostgREST syntax](https://postgrest.org/en/stable/api.html#operators). You also need to make sure they are properly sanitized.

  ## Parameters
  - `column` - The column to filter on
  - `operator` - The operator to filter with, following PostgREST syntax
  - `value` - The value to filter with, following PostgREST syntax, must implement the `String.Chars` protocol

  ## Examples
      iex> PostgREST.filter(builder, "id", "not", 12)
  """
  @impl true
  def filter(%Request{} = b, column, op, value)
      when is_binary(column) and is_filter_op(op) do
    condition = process_condition({op, column, value})
    Request.with_query(b, %{column => condition})
  end

  @doc """
  Applies an "AND" condition to a query, allowing multiple conditions on different columns.
  This can also be scoped to a foreign table if specified.

  Unlike most filters, `filters` is used as-is and needs to follow [PostgREST syntax](https://postgrest.org/en/stable/api.html#operators). You also need to make sure it's properly sanitized.

  It's currently not possible to do an `.and()` filter across multiple tables.

  You can optionally use the custom DSL to represent conditions instead of a raw string, look at the examples and the `Supabase.PostgREST.FilterBuilder.Behaviour.condition()` type spec.

  ## Parameters
  - `builder`: The `Supabase.Fetcher.Request` instance.
  - `columns`: A list of conditions that should all be met.
  - `opts`: Optional parameters, which can include specifying a foreign table.

  ## Examples
      iex> PostgREST.all_of(builder, [{:gt, "age", 18}, {:eq, "status", "active"}])
      iex> PostgREST.all_of([
      iex>      {:gt, "age", 18},
      iex>      {:and, [
      iex>        {:lt, "salary", 5000},
      iex>        {:eq, "role", "junior"}
      iex>      ]}
      iex>    ])

  ## See also
  - Supabase logical operations: https://supabase.com/docs/reference/javascript/using-filters#logical-operators
  """
  @impl true
  def all_of(builder, patterns, opts \\ [])

  def all_of(%Request{} = b, patterns, opts) when is_binary(patterns) do
    if foreign = Keyword.get(opts, :foreign_table) do
      Request.with_query(b, %{"#{foreign}.and" => "(#{patterns})"})
    else
      Request.with_query(b, %{"and" => "(#{patterns})"})
    end
  end

  def all_of(%Request{} = b, patterns, opts) when is_list(patterns) do
    filters = Enum.map_join(patterns, ",", &process_condition/1)

    if foreign = Keyword.get(opts, :foreign_table) do
      Request.with_query(b, %{"#{foreign}.and" => "(#{filters})"})
    else
      Request.with_query(b, %{"and" => "(#{filters})"})
    end
  end

  @doc """
  Applies an "OR" condition to a query, combining multiple conditions on different columns
  where at least one condition must be met. This can also be scoped to a foreign table.

  Unlike most filters, `filters` is used as-is and needs to follow [PostgREST syntax](https://postgrest.org/en/stable/api.html#operators). You also need to make sure it's properly sanitized.

  It's currently not possible to do an `.and()` filter across multiple tables.

  You can optionally use the custom DSL to represent conditions instead of a raw string, look at the examples and the `Supabase.PostgREST.FilterBuilder.Behaviour.condition()` type spec.

  ## Parameters
  - `builder`: The `Supabase.Fetcher.Request` instance.
  - `columns`: A list of conditions where at least one should be met.
  - `opts`: Optional parameters, which can include specifying a foreign table.

  ## Examples
      iex> PostgREST.any_of(builder, [{:gt, "age", 18}, {:eq, "status", "active"}])
      iex> PostgREST.any_of([
      iex>      {:gt, "age", 18},
      iex>      {:or, [
      iex>        {:eq, "status", "active"},
      iex>        {:eq, "status", "pending"}
      iex>      ]},
      iex>    ])

  ## See also
  - Further details on logical operations in Supabase: https://supabase.com/docs/reference/javascript/using-filters#logical-operators
  """
  @impl true
  def any_of(builder, patterns, opts \\ [])

  def any_of(%Request{} = b, patterns, opts) when is_binary(patterns) do
    if foreign = Keyword.get(opts, :foreign_table) do
      Request.with_query(b, %{"#{foreign}.or" => "(#{patterns})"})
    else
      Request.with_query(b, %{"or" => "(#{patterns})"})
    end
  end

  def any_of(%Request{} = b, patterns, opts) when is_list(patterns) do
    filters = Enum.map_join(patterns, ",", &process_condition/1)

    if foreign = Keyword.get(opts, :foreign_table) do
      Request.with_query(b, %{"#{foreign}.or" => "(#{filters})"})
    else
      Request.with_query(b, %{"or" => "(#{filters})"})
    end
  end

  @doc """
  Applies a "NOT" condition to the query, negating a specified condition.

  Unlike most filters, `opearator` and `value` are used as-is and need to
  follow [PostgREST syntax](https://postgrest.org/en/stable/api.html#operators). You also need
  to make sure they are properly sanitized.

  ## Parameters
  - `builder`: The `Supabase.Fetcher.Request` instance.
  - `column`: The column to apply the negation.
  - `op`: The operator used in the condition (e.g., "eq", "gt").
  - `value`: The value to compare against, must implement the `String.Chars` protocol

  ## Examples
      iex> PostgREST.not(builder, "status", "eq", "active")

  ## See also
  - Supabase negation filters: https://supabase.com/docs/reference/javascript/using-filters#negation
  """
  @impl true
  def negate(%Request{} = b, column, op, value)
      when is_binary(column) and is_filter_op(op) do
    Request.with_query(b, %{column => "not.#{op}.#{value}"})
  end

  alias Supabase.PostgREST.FilterBuilder.Behaviour, as: Interface

  defguardp is_op_mod(op) when op in [:eq, :like, :ilike, :gt, :gte, :lt, :lte, :match, :imatch]
  defguardp is_fts_op(op) when op in [:fts, :plfts, :phfts, :wfts]

  @spec process_condition(Interface.condition()) :: String.t()
  def process_condition({:not, condition}) do
    "not.#{process_condition(condition)}"
  end

  def process_condition({:and, conditions}) when is_list(conditions) do
    "and(#{Enum.map_join(conditions, ",", &process_condition/1)})"
  end

  def process_condition({:or, conditions}) when is_list(conditions) do
    "or(#{Enum.map_join(conditions, ",", &process_condition/1)})"
  end

  def process_condition({op, column, values, opts})
      when is_list(values) and is_op_mod(op) do
    op = to_string(op)
    all = Keyword.get(opts, :all, false)
    any = Keyword.get(opts, :any, false)

    cond do
      all -> Enum.join([op <> "(all)", "{#{Enum.join(values, ",")}}"], ".")
      any -> Enum.join([op <> "(any)", "{#{Enum.join(values, ",")}}"], ".")
      true -> Enum.join([op, "{#{Enum.join(values, ",")}}"], ".")
    end
    |> then(&(column <> "=" <> &1))
  end

  def process_condition({op, column, value, lang: lang}) when is_fts_op(op) do
    "#{column}=#{op}(#{lang}).#{value}"
  end

  def process_condition({op, column, value}) when is_filter_op(op) do
    formatted_value =
      case {op, value} do
        {:in, values} when is_list(values) -> "(#{Enum.join(values, ",")})"
        {:is, nil} -> "null"
        {_, values} when is_list(values) -> "[#{Enum.join(values, ",")}]"
        {_, v} -> v
      end

    Enum.join([column, op, formatted_value], ".")
  end

  # Handle between operator separately
  def process_condition({:between, column, [from, to]}) do
    "#{column}.between.[#{from},#{to}]"
  end

  @doc """
  Match only rows where each column in `query` keys is equal to its associated value. Shorthand for multiple `.eq()`s.

  ## Parameters
  - `query` - The object to filter with, with column names as keys mapped to their filter values, and all values must implement the `String.Chars` protocol

  ## Examples
  iex> PostgREST.match(builder, %{"col1" => true, "col2" => false})

  ## See also
  - Supabase ordering results: https://supabase.com/docs/reference/javascript/using-filters#match
  """
  @impl true
  def match(%Request{} = b, %{} = query) do
    for {k, v} <- Map.to_list(query), reduce: b do
      b -> Request.with_query(b, %{k => "eq.#{v}"})
    end
  end

  @doc """
  Match only rows where `column` is equal to `value`.

  To check if the value of `column` is NULL, you should use `.is()` instead.

  ## Parameters
  - `builder`: The `Supabase.Fetcher.Request` instance.
  - `column`: The column to apply the filter.
  - `value`: The value the column must equal, must implement `String.Chars` protocol

  ## Examples
      iex> PostgREST.eq(builder, "id", 123)

  ## See also
  - Supabase equality filters: https://supabase.com/docs/reference/javascript/using-filters#equality
  """
  @impl true
  def eq(%Request{} = f, column, value) when is_binary(column) do
    Request.with_query(f, %{column => "eq.#{value}"})
  end

  @doc """
  Match only rows where `column` is not equal to `value`.

  ## Parameters
  - `builder`: The `Supabase.Fetcher.Request` instance.
  - `column`: The column to apply the filter.
  - `value`: The value that the column must not equal, must implement `String.Chars` protocol

  ## Examples
      iex> PostgREST.neq(builder, "status", "inactive")

  ## See also
  - Supabase not equal filter: https://supabase.com/docs/reference/javascript/using-filters#not-equal
  """
  @impl true
  def neq(%Request{} = f, column, value) when is_binary(column) do
    Request.with_query(f, %{column => "neq.#{value}"})
  end

  @doc """
  Adds a 'greater than' filter to the query, specifying that the column's value must be greater than the specified value.

  ## Parameters
  - `builder`: The `Supabase.Fetcher.Request` instance.
  - `column`: The column to apply the filter.
  - `value`: The value that the column must be greater than, must implement the `String.Chars` protocol

  ## Examples
      iex> PostgREST.gt(builder, "age", 21)

  ## See also
  - Supabase greater than filter: https://supabase.com/docs/reference/javascript/using-filters#greater-than
  """
  @impl true
  def gt(%Request{} = f, column, value) when is_binary(column) do
    Request.with_query(f, %{column => "gt.#{value}"})
  end

  @doc """
  Adds a 'greater than or equal to' filter to the query, specifying that the column's value must be greater than or equal to the specified value.

  ## Parameters
  - `builder`: The `Supabase.Fetcher.Request` instance.
  - `column`: The column to apply the filter.
  - `value`: The value that the column must be greater than or equal to, must implement the `String.Chars` protocol

  ## Examples
      iex> PostgREST.gte(builder, "age", 21)

  ## See also
  - Supabase greater than or equal filter: https://supabase.com/docs/reference/javascript/using-filters#greater-than-or-equal
  """
  @impl true
  def gte(%Request{} = f, column, value) when is_binary(column) do
    Request.with_query(f, %{column => "gte.#{value}"})
  end

  @doc """
  Adds a 'less than' filter to the query, specifying that the column's value must be less than the specified value.

  ## Parameters
  - `builder`: The `Supabase.Fetcher.Request` instance.
  - `column`: The column to apply the filter.
  - `value`: The value that the column must be less than, must implement the `String.Chars` protocol

  ## Examples
      iex> PostgREST.lt(builder, "age", 65)

  ## See also
  - Supabase less than filter: https://supabase.com/docs/reference/javascript/using-filters#less-than
  """
  @impl true
  def lt(%Request{} = f, column, value) when is_binary(column) do
    Request.with_query(f, %{column => "lt.#{value}"})
  end

  @doc """
  Adds a 'less than or equal to' filter to the query, specifying that the column's value must be less than or equal to the specified value.

  ## Parameters
  - `builder`: The `Supabase.Fetcher.Request` instance.
  - `column`: The column to apply the filter.
  - `value`: The value that the column must be less than or equal to, must implement the `String.Chars` protocol

  ## Examples
      iex> PostgREST.lte(builder, "age", 65)

  ## See also
  - Supabase less than or equal filter: https://supabase.com/docs/reference/javascript/using-filters#less-than-or-equal
  """
  @impl true
  def lte(%Request{} = f, column, value) when is_binary(column) do
    Request.with_query(f, %{column => "lte.#{value}"})
  end

  @doc """
  Adds a 'like' filter to the query, allowing for simple pattern matching (SQL LIKE).

  ## Parameters
  - `builder`: The `Supabase.Fetcher.Request` instance.
  - `column`: The column to apply the filter.
  - `value`: The pattern to match against the column's value, must implement the `String.Chars` protocol

  ## Examples
      iex> PostgREST.like(builder, "name", "%John%")

  ## See also
  - Supabase like filter: https://supabase.com/docs/reference/javascript/using-filters#like
  """
  @impl true
  def like(%Request{} = f, column, value) when is_binary(column) do
    Request.with_query(f, %{column => "like.#{value}"})
  end

  @doc """
  Match only rows where `column` matches **all** of `patterns` case-sensitively.

  ## Params
  - `column`: the column to apply the filter
  - `values`: a list of patterns of filters (needs to implement the `String.Chars` protocol)

  ## Examples
      iex> PostgREST.like_all_of(builder, "name", ["jhon", "maria", "joão"])
  """
  @impl true
  def like_all_of(%Request{} = b, column, values)
      when is_binary(column) and is_list(values) do
    Request.with_query(b, %{column => "like(all).{#{Enum.join(values, ",")}}"})
  end

  @doc """
  Match only rows where `column` matches **any** of `patterns` case-sensitively.

  ## Params
  - `column`: the column to apply the filter
  - `values`: a list of patterns of filters (needs to implement the `String.Chars` protocol)

  ## Examples
      iex> PostgREST.like_any_of(builder, "name", ["jhon", "maria", "joão"])
  """
  @impl true
  def like_any_of(%Request{} = b, column, values)
      when is_binary(column) and is_list(values) do
    Request.with_query(b, %{column => "like(any).{#{Enum.join(values, ",")}}"})
  end

  @doc """
  Adds an 'ilike' filter to the query, allowing for case-insensitive pattern matching (SQL ILIKE).

  ## Parameters
  - `builder`: The `Supabase.Fetcher.Request` instance.
  - `column`: The column to apply the filter.
  - `value`: The pattern to match against the column's value, ignoring case, must implement the `String.Chars` protocol

  ## Examples
      iex> PostgREST.ilike(builder, "name", "%john%")

  ## See also
  - Supabase ilike filter: https://supabase.com/docs/reference/javascript/using-filters#ilike
  """
  @impl true
  def ilike(%Request{} = f, column, value) when is_binary(column) do
    Request.with_query(f, %{column => "ilike.#{value}"})
  end

  @doc """
  Match only rows where `column` matches **all** of `patterns` case-insensitively.

  ## Params
  - `column`: the column to apply the filter
  - `values`: a list of patterns of filters (needs to implement the `String.Chars` protocol)

  ## Examples
      iex> PostgREST.ilike_all_of(builder, "name", ["jhon", "maria", "joão"])
  """
  @impl true
  def ilike_all_of(%Request{} = f, column, values)
      when is_binary(column) and is_list(values) do
    Request.with_query(f, %{column => "ilike(all).{#{Enum.join(values, ",")}}"})
  end

  @doc """
  Match only rows where `column` matches **any** of `patterns` case-insensitively.

  ## Params
  - `column`: the column to apply the filter
  - `values`: a list of patterns of filters (needs to implement the `String.Chars` protocol)

  ## Examples
      iex> PostgREST.ilike_any_of(builder, "name", ["jhon", "maria", "joão"])
  """
  @impl true
  def ilike_any_of(%Request{} = f, column, values)
      when is_binary(column) and is_list(values) do
    Request.with_query(f, %{column => "ilike(any).{#{Enum.join(values, ",")}}"})
  end

  @doc """
  Match only rows where `column` IS `value`.

  For non-boolean columns, this is only relevant for checking if the value of
  `column` is NULL by setting `value` to `nil`.

  For boolean columns, you can also set `value` to `true` or `false` and it
  will behave the same way as `.eq()`.

  ## Parameters
  - `builder`: The `Supabase.Fetcher.Request` instance.
  - `column`: The column to apply the filter.
  - `value`: The value to check the column against (typically nil or a boolean).

  ## Examples
      iex> PostgREST.is(builder, "name", nil)

  ## See also
  - Supabase is filter: https://supabase.com/docs/reference/javascript/using-filters#is
  """
  @impl true
  def is(%Request{} = f, column, nil) when is_binary(column) do
    Request.with_query(f, %{column => "is.null"})
  end

  def is(%Request{} = f, column, value) when is_binary(column) and is_boolean(value) do
    Request.with_query(f, %{column => "is.#{value}"})
  end

  @doc """
  Filters the query by checking if the column's value is within an array of specified values.

  ## Parameters
  - `builder`: The `Supabase.Fetcher.Request` instance.
  - `column`: The column to filter.
  - `values`: A list of acceptable values for the column, all elements must implement the `String.Chars` protocol

  ## Examples
      iex> PostgREST.in(builder, "status", ["active", "pending", "closed"])

  ## See also
  - Supabase "IN" filters: https://supabase.com/docs/reference/javascript/using-filters#in
  """
  @impl true
  def within(%Request{} = f, column, values)
      when is_binary(column) and is_list(values) do
    values =
      Enum.map_join(values, ",", fn v ->
        if String.match?(v, ~r/[,()]/), do: "#{to_string(v)}", else: to_string(v)
      end)

    Request.with_query(f, %{column => "in.(#{values})"})
  end

  @doc """
  Only relevant for jsonb, array, and range columns. Match only rows where `column` contains every element appearing in `value`.

  ## Parameters
  - `builder`: The `Supabase.Fetcher.Request` instance.
  - `column`: The column to apply the filter.
  - `values`: It can be a single value (string), a list of values to filter or a map (aka json)

  ## Examples
      iex> PostgREST.contains(builder, "tags", ["urgent", "new"])

  ## See also
  - Supabase contains filter: https://supabase.com/docs/reference/javascript/using-filters#contains
  """
  @impl true
  def contains(%Request{} = b, column, value)
      when is_binary(column) and is_binary(value) do
    do_contains(b, column, value)
  end

  def contains(%Request{} = b, column, values)
      when is_binary(column) and is_list(values) do
    do_contains(b, column, "{#{Enum.join(values, ",")}}")
  end

  def contains(%Request{} = b, column, values)
      when is_binary(column) and is_map(values) do
    json = Supabase.json_library()
    do_contains(b, column, json.encode!(values))
  end

  defp do_contains(%Request{} = b, column, value) do
    Request.with_query(b, %{column => "cs.#{value}"})
  end

  @doc """
  Only relevant for jsonb, array, and range columns. Match only rows where every element appearing in `column` is contained by `value`.

  ## Parameters
  - `builder`: The `Supabase.Fetcher.Request` instance.
  - `column`: The column to apply the filter.
  - `values`: It can be a single value (string), a list of values to filter or a map (aka json)

  ## Examples
      iex> PostgREST.contained_by(builder, "tags", ["urgent", "new", "old"])

  ## See also
  - Supabase contained by filter: https://supabase.com/docs/reference/javascript/using-filters#contained-by
  """
  @impl true
  def contained_by(%Request{} = b, column, value)
      when is_binary(column) and is_binary(value) do
    do_contained_by(b, column, value)
  end

  def contained_by(%Request{} = b, column, values)
      when is_binary(column) and is_list(values) do
    do_contained_by(b, column, "{#{Enum.join(values, ",")}}")
  end

  def contained_by(%Request{} = b, column, values)
      when is_binary(column) and is_map(values) do
    json = Supabase.json_library()
    do_contained_by(b, column, json.encode!(values))
  end

  defp do_contained_by(%Request{} = b, column, value) do
    Request.with_query(b, %{column => "cd.#{value}"})
  end

  @doc """
  Only relevant for range columns. Match only rows where every element in `column` is less than any element in `range`.

  ## Parameters
  - `builder`: The `Supabase.Fetcher.Request` instance.
  - `column`: The column to apply the filter.
  - `value`: The upper bound value of the range, must implement the `String.Chars` protocol

  ## Examples
      iex> PostgREST.range_lt(builder, "age", 30)

  ## See also
  - Supabase range filters: https://supabase.com/docs/reference/javascript/using-filters#range
  """
  @impl true
  def range_lt(%Request{} = f, column, value) when is_binary(column) do
    Request.with_query(f, %{column => "sl.#{value}"})
  end

  @doc """
  Only relevant for range columns. Match only rows where every element in `column` is greater than any element in `range`.

  ## Parameters
  - `builder`: The Request instance.
  - `column`: The column to apply the filter.
  - `value`: The lower bound value of the range, must implement the `String.Chars` protocol

  ## Examples
      iex> PostgREST.range_gt(builder, "age", 20)

  ## See also
  - More on range filters at Supabase: https://supabase.com/docs/reference/javascript/using-filters#range
  """
  @impl true
  def range_gt(%Request{} = f, column, value) when is_binary(column) do
    Request.with_query(f, %{column => "sr.#{value}"})
  end

  @doc """
  Only relevant for range columns. Match only rows where every element in `column` is either contained in `range` or greater than any element in `range`.

  ## Parameters
  - `builder`: The Request instance.
  - `column`: The column to apply the filter.
  - `value`: The starting value of the range, must implement the `String.Chars` protocol

  ## Examples
      iex> PostgREST.range_gte(builder, "age", 18)

  ## See also
  - Supabase documentation on range filters: https://supabase.com/docs/reference/javascript/using-filters#range
  """
  @impl true
  def range_gte(%Request{} = f, column, value) when is_binary(column) do
    Request.with_query(f, %{column => "nxl.#{value}"})
  end

  @doc """
  Only relevant for range columns. Match only rows where every element in `column` is either contained in `range` or less than any element in `range`.

  ## Parameters
  - `builder`: The Request instance.
  - `column`: The column to apply the filter.
  - `value`: The ending value of the range, must implement the `String.Chars` protocol

  ## Examples
      iex> PostgREST.range_lte(builder, "age", 65)

  ## See also
  - Supabase guide on using range filters: https://supabase.com/docs/reference/javascript/using-filters#range
  """
  @impl true
  def range_lte(%Request{} = f, column, value) when is_binary(column) do
    Request.with_query(f, %{column => "nxr.#{value}"})
  end

  @doc """
  Only relevant for range columns. Match only rows where `column` is mutually exclusive to `range` and there can be no element between the two ranges.

  ## Parameters
  - `builder`: The `Supabase.Fetcher.Request` instance.
  - `column`: The column to apply the filter.
  - `value`: The adjacent range value, must implement the `String.Chars` protocol

  ## Examples
      iex> PostgREST.range_adjacent(builder, "scheduled_time", "2021-01-01T10:00:00Z/2021-01-01T12:00:00Z")

  ## See also
  - Supabase adjacent range filters: https://supabase.com/docs/reference/javascript/using-filters#adjacent
  """
  @impl true
  def range_adjacent(%Request{} = f, column, value) when is_binary(column) do
    Request.with_query(f, %{column => "adj.#{value}"})
  end

  @doc """
  Only relevant for array and range columns. Match only rows where `column` and `value` have an element in common.

  ## Parameters
  - `builder`: The `Supabase.Fetcher.Request` instance.
  - `column`: The column to apply the filter.
  - `values`: The array of values that must overlap with the column's value, all elements must implement the `String.Chars` protocol

  ## Examples
      iex> PostgREST.overlaps(builder, "tags", ["urgent", "old"])

  ## See also
  - Supabase overlaps filter: https://supabase.com/docs/reference/javascript/using-filters#overlaps
  """
  @impl true
  def overlaps(%Request{} = b, column, value)
      when is_binary(column) and is_binary(value) do
    Request.with_query(b, %{column => "ov.#{value}"})
  end

  def overlaps(%Request{} = b, column, values)
      when is_binary(column) and is_list(values) do
    values
    |> Enum.join(",")
    |> then(&Request.with_query(b, %{column => "ov.{#{&1}}"}))
  end

  @doc """
  Only relevant for text and tsvector columns. Match only rows where `column` matches the query string in `query`.

  ## Parameters
  - `builder`: The `Supabase.Fetcher.Request` instance.
  - `column`: The column to search.
  - `query`: The text query for the search.
  - `opts`: Options for the search, such as type of search (`:plain`, `:phrase`, or `:websearch`) and configuration.

  ## Examples
      iex> PostgREST.text_search(builder, "description", "elixir supabase", type: :plain)

  ## See also
  - Supabase full-text search capabilities: https://supabase.com/docs/reference/javascript/using-filters#full-text-search
  """
  @impl true
  def text_search(%Request{} = f, column, query, opts \\ []) when is_binary(column) do
    type = search_type_to_code(Keyword.get(opts, :type))
    config = if config = Keyword.get(opts, :config), do: "(#{config})", else: ""

    Request.with_query(f, %{column => "#{type}fts#{config}.#{query}"})
  end

  defp search_type_to_code(:plain), do: "pl"
  defp search_type_to_code(:phrase), do: "ph"
  defp search_type_to_code(:websearch), do: "w"
  defp search_type_to_code(nil), do: nil
end
