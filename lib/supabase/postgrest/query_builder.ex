defmodule Supabase.PostgREST.QueryBuilder do
  @moduledoc """
  Handles operations related to building and modifying the main structure of a query.

  This module includes functionality for selecting fields, inserting new records, updating existing ones, and deleting records from a specified table. These operations define the high-level intent of the query, such as whether it retrieves, modifies, or removes data.
  """

  alias Supabase.Fetcher.Request

  @behaviour Supabase.PostgREST.QueryBuilder.Behaviour

  @doc """
  Selects records from a table. You can specify specific columns or use '*' for all columns.
  Options such as counting results and specifying return types can be configured.

  Note that this function does not return by default, it only build the select
  expression for the query. If you want to have the selected fields returned as
  response you need to pass `returning: true`.

  ## Parameters
  - `builder`: The `Supabase.Fetcher.Request` instance.
  - `columns`: A list of column names to fetch or '*' for all columns.
  - `opts`: Options such as `:count` and `:returning`.

  ## Examples
      iex> PostgREST.select(builder, "*", count: :exact, returning: true)

  ## See also
  - Supabase select queries: https://supabase.com/docs/reference/javascript/select
  """
  @impl true
  def select(builder, columns, opts \\ [])

  def select(%Request{} = b, "*", opts) do
    do_select(b, "*", opts)
  end

  def select(%Request{} = b, columns, opts)
      when is_list(columns) do
    do_select(b, Enum.join(columns, ","), opts)
  end

  @spec do_select(Request.t(), String.t(), keyword) :: Request.t()
  defp do_select(%Request{} = b, columns, opts) do
    count = Keyword.get(opts, :count, :exact)
    returning = Keyword.get(opts, :returning, false)

    b
    |> Request.with_method(:get)
    |> Request.with_query(%{"select" => columns})
    |> Request.with_headers(%{"prefer" => "count=#{count}"})
    |> then(fn builder ->
      if returning do
        Request.with_method(builder, :get)
      else
        Request.with_method(builder, :head)
      end
    end)
  end

  @doc """
  Inserts new records into the database. Supports conflict resolution and specifying how the
  result should be returned.

  ## Parameters
  - `builder`: The `Supabase.Fetcher.Request` to use.
  - `data`: The data to be inserted, typically a map or a list of maps.
  - `opts`: Options like `:on_conflict`, `:returning`, and `:count`.

  ## Examples
      iex> PostgREST.insert(builder, %{name: "John"}, on_conflict: "name", returning: :minimal)

  ## See also
  - Supabase documentation on inserts: https://supabase.com/docs/reference/javascript/insert
  """
  @impl true
  def insert(%Request{} = b, data, opts \\ []) when is_map(data) do
    on_conflict = Keyword.get(opts, :on_conflict)
    on_conflict_header = if on_conflict, do: "on_conflict=#{on_conflict}"
    upsert = if on_conflict, do: "resolution=merge-duplicates"
    returning = Keyword.get(opts, :returning, :representation)
    count = Keyword.get(opts, :count, :exact)
    prefer = ["return=#{returning}", "count=#{count}", on_conflict_header, upsert]
    prefer = Enum.join(Enum.reject(prefer, &is_nil/1), ",")

    b
    |> Request.with_method(:post)
    |> Request.with_headers(%{"prefer" => prefer})
    |> maybe_add_conflict_query(on_conflict)
    |> Request.with_body(data)
  end

  defp maybe_add_conflict_query(request, nil), do: request

  defp maybe_add_conflict_query(request, on_conflict) do
    Request.with_query(request, %{"on_conflict" => on_conflict})
  end

  @doc """
  Upserts data into a table, allowing for conflict resolution and specifying return options.

  ## Parameters
  - `builder`: The `Supabase.Fetcher.Request` to use.
  - `data`: The data to upsert, typically a map or a list of maps.
  - `opts`: Options like `:on_conflict`, `:returning`, and `:count`.

  ## Examples
      iex> PostgREST.upsert(builder, %{name: "Jane"}, on_conflict: "name", returning: :representation)

  ## See also
  - Supabase documentation on upserts: https://supabase.com/docs/reference/javascript/upsert
  """
  @impl true
  def upsert(%Request{} = b, data, opts \\ []) when is_map(data) do
    on_conflict = Keyword.get(opts, :on_conflict)
    on_conflict_header = if on_conflict, do: "on_conflict=#{on_conflict}"
    returning = Keyword.get(opts, :returning, :representation)
    count = Keyword.get(opts, :count, :exact)

    prefer_parts = [
      "resolution=merge-duplicates",
      "return=#{returning}",
      "count=#{count}",
      on_conflict_header
    ]

    prefer = Enum.join(Enum.reject(prefer_parts, &is_nil/1), ",")

    b
    |> Request.with_method(:post)
    |> Request.with_headers(%{"prefer" => prefer})
    |> maybe_add_conflict_query(on_conflict)
    |> Request.with_body(data)
  end

  @doc """
  Deletes records from a table based on the conditions specified.

  ## Parameters
  - `builder`: The `Supabase.Fetcher.Request` to use.
  - `opts`: Options such as `:returning` and `:count`.

  ## Examples
      iex> PostgREST.delete(builder, returning: :representation)

  ## See also
  - Supabase documentation on deletes: https://supabase.com/docs/reference/javascript/delete
  """
  @impl true
  def delete(%Request{} = b, opts \\ []) do
    returning = Keyword.get(opts, :returning, :representation)
    count = Keyword.get(opts, :count, :exact)
    prefer = Enum.join(["return=#{returning}", "count=#{count}"], ",")

    b
    |> Request.with_method(:delete)
    |> Request.with_headers(%{"prefer" => prefer})
  end

  @doc """
  Updates existing records in the database. Allows specifying return options and how the update is counted.

  ## Parameters
  - `builder`: The `Supabase.Fetcher.Request` to use.
  - `data`: The new data for the update, typically a map or list of maps.
  - `opts`: Options such as `:returning` and `:count`.

  ## Examples
      iex> PostgREST.update(builder, %{name: "Doe"}, returning: :representation)

  ## See also
  - Supabase documentation on updates: https://supabase.com/docs/reference/javascript/update
  """
  @impl true
  def update(%Request{} = b, data, opts \\ []) when is_map(data) do
    returning = Keyword.get(opts, :returning, :representation)
    count = Keyword.get(opts, :count, :exact)
    prefer = Enum.join(["return=#{returning}", "count=#{count}"], ",")

    b
    |> Request.with_method(:patch)
    |> Request.with_headers(%{"prefer" => prefer})
    |> Request.with_body(data)
  end

  # aggregation helpers

  defguardp is_column(c) when is_binary(c) or is_atom(c)

  @aggregators [:sum, :avg, :min, :max, :count]

  for agg <- @aggregators do
    @doc """
    Hleper function to apply aggregation of #{agg} function to a specified
    column name. This should be used on `select/3`.

    ## Parameters
    - `column`: The `Supabase.Fetcher.Request` to use.
    - `opts.as`: If specifying more than one aggregate function for the same column, you may need to rename it, so you can pass an optional `:as` value for it.

    ## Examples
        iex> alias Supabase.PostgREST, as: Q
        iex> Q.select(builder, [Q.avg("amount")])

        iex> alias Supabase.PostgREST, as: Q
        iex> Q.select(builder, [Q.avg("amount", as: "avg_amount"), Q.sum("amount", as: "total_amount")])

    ## See also
    - PostgREST official docs about aggregation functions: https://docs.postgrest.org/en/stable/references/api/aggregate_functions.html
    """
    @impl true
    def unquote(agg)(column, opts \\ []) when is_column(column) do
      if as = Keyword.get(opts, :as) do
        "#{as}:#{column}.#{to_string(unquote(agg))}()"
      else
        "#{column}.#{to_string(unquote(agg))}()"
      end
    end
  end
end
