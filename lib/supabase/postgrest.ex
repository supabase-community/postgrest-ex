defmodule Supabase.PostgREST do
  @moduledoc """
  Provides a suite of functions to interact with a Supabase PostgREST API, allowing
  for construction and execution of queries using a fluent interface. This module is designed
  to facilitate the building of complex queries and their execution in the context of a Supabase
  database application.

  For detailed usage examples and more information, refer to the official Supabase documentation:
  https://supabase.com/docs
  """

  alias Supabase.Client
  alias Supabase.Fetcher
  alias Supabase.Fetcher.JSONDecoder
  alias Supabase.Fetcher.Request
  alias Supabase.Fetcher.Response
  alias Supabase.PostgREST.Error

  alias Supabase.PostgREST.FilterBuilder
  alias Supabase.PostgREST.QueryBuilder
  alias Supabase.PostgREST.TransformBuilder

  @behaviour Supabase.PostgREST.Behaviour

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

  ## Query Builder

  for {fun, arity} <- QueryBuilder.__info__(:functions) do
    1..arity
    |> Enum.map(&Macro.var(:"arg_#{&1}", QueryBuilder))
    |> then(fn args ->
      defdelegate unquote(fun)(unquote_splicing(args)), to: QueryBuilder
    end)
  end

  ## Filter Builder

  for {fun, arity} <- FilterBuilder.__info__(:functions), fun != :process_condition do
    1..arity
    |> Enum.map(&Macro.var(:"arg_#{&1}", QueryBuilder))
    |> then(fn args ->
      defdelegate unquote(fun)(unquote_splicing(args)), to: FilterBuilder
    end)
  end

  ## Transform Builder

  for {fun, arity} <- TransformBuilder.__info__(:functions) do
    1..arity
    |> Enum.map(&Macro.var(:"arg_#{&1}", QueryBuilder))
    |> then(fn args ->
      defdelegate unquote(fun)(unquote_splicing(args)), to: TransformBuilder
    end)
  end

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
    |> Request.new()
    |> Request.with_database_url(table)
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
  def schema(%Request{} = b, schema) when is_binary(schema) do
    put_in(b.client.db.schema, schema)
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
  def with_custom_media_type(%Request{} = b, media_type)
      when is_atom(media_type) do
    header = @accept_headers[media_type] || @accept_headers[:default]
    Request.with_headers(b, %{"accept" => header})
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
  def execute(%Request{} = b), do: do_execute(b)

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
  def execute_to(%Request{} = b, schema) when is_atom(schema) do
    alias Supabase.PostgREST.SchemaDecoder

    Request.with_body_decoder(b, SchemaDecoder, schema: schema)
    |> do_execute()
  end

  @doc """
  Builds a query using the Finch HTTP client, formatting the request appropriately. Returns the HTTP request without executing it.

  ## Parameters
  - `builder`: The Builder or Builder instance to execute.

  ## Examples
      iex> PostgREST.execute_to_finch_request(builder)

  ## See also
  - Supabase query execution: https://supabase.com/docs/reference/javascript/performing-queries
  """
  @impl true
  def execute_to_finch_request(%Request{} = b) do
    query = URI.encode_query(b.query)
    url = URI.parse(b.url) |> URI.append_query(query)

    Finch.build(b.method, url, b.headers, b.body)
  end

  defp do_execute(%Request{client: client} = b) do
    schema = client.db.schema

    schema_header =
      if b.method in [:get, :head],
        do: %{"accept-profile" => schema},
        else: %{"content-profile" => schema}

    b
    |> Request.with_error_parser(Error)
    |> Request.with_headers(schema_header)
    |> Fetcher.request()
  end

  @doc """
  Perform a function call.

  This function returns a `Supabase.Fetcher.Request` builder that can be safely
  pipelined to `Supabase.PostgREST.FilterBuilder` functions.

  ## Params

  - `client`: The `Supabase.Client` to perform the function call.
  - `fn`: The function name to call.
  - `args`: The arguments to pass to the function call as a map.
  - `options`: Named parameters:
    - `options.head`: When set to `true`, `data` will not be returned. Useful if you only need the count.
    - `options.get`: When set to `true`, the function will be called with read-only access mode.
    - `options.count`: Count algorithm to use to count rows returned by the function. Only applicable for [set-returning functions](https://www.postgresql.org/docs/current/functions-srf.html).
      * `"exact"`: Exact but slow count algorithm. Performs a `COUNT(*)` under the hood.
      * `"planned"`: Approximated but fast count algorithm. Uses the Postgres statistics under the hood.
      * `"estimated"`: Uses exact count for low numbers and planned count for high numbers.
  """
  @impl true
  def rpc(client, function, args \\ %{}, opts \\ [])

  def rpc(%Client{} = client, function, %{} = args, opts) when is_binary(function) do
    head? = opts[:head] || false
    get? = opts[:get] || false
    count = opts[:count]

    client
    |> Request.new()
    |> Request.with_body_decoder(&decode_only_error/2)
    |> Request.with_error_parser(Error)
    |> Request.with_database_url("rpc/#{function}")
    |> maybe_append_body(head? or get?, args)
    |> maybe_change_method(head: head?, get: get?)
    |> maybe_append_rpc_query(args)
    |> maybe_append_count_header(count)
  end

  defp decode_only_error(%Response{} = resp, _opts) do
    with {:error, _} <- JSONDecoder.decode(resp, keys: :atoms) do
      {:ok, resp.body}
    end
  end

  defp maybe_append_body(%Request{} = b, true, _), do: b

  defp maybe_append_body(%Request{} = b, false, %{} = args) do
    Request.with_body(b, args) |> Request.with_method(:post)
  end

  defp maybe_change_method(%Request{} = b, head: false, get: true) do
    Request.with_method(b, :get)
  end

  defp maybe_change_method(%Request{} = b, head: true, get: false) do
    Request.with_method(b, :head)
  end

  defp maybe_change_method(%Request{} = b, head: false, get: false), do: b

  defp maybe_append_rpc_query(%Request{method: method} = b, %{} = args)
       when method in [:head, :get] do
    Enum.reject(args, fn {_k, v} -> is_nil(v) end)
    |> Enum.map(fn
      {k, v} when is_list(v) -> {to_string(k), "{#{Enum.join(v, ",")}}"}
      {k, v} -> {to_string(k), v}
    end)
    |> then(&Request.with_query(b, &1))
  end

  defp maybe_append_rpc_query(%Request{} = b, _), do: b

  defp maybe_append_count_header(%Request{} = b, count)
       when count in [:exact, :planned, :estimated] do
    Request.with_headers(b, %{"prefer" => "count=#{to_string(count)}"})
  end

  defp maybe_append_count_header(%Request{} = b, _), do: b
end
