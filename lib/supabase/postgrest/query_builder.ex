defmodule Supabase.PostgREST.QueryBuilder do
  @moduledoc """
  Handles operations related to building and modifying the main structure of a query.

  This module includes functionality for selecting fields, inserting new records, updating existing ones, and deleting records from a specified table. These operations define the high-level intent of the query, such as whether it retrieves, modifies, or removes data.
  """

  alias Supabase.PostgREST.Builder

  @behaviour Supabase.PostgREST.QueryBuilder.Behaviour

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
end
