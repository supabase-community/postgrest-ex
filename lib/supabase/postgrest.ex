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
  alias Supabase.PostgREST.Builder
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
    (1..arity)
    |> Enum.map(&Macro.var(:"arg_#{&1}", QueryBuilder))
    |> then(fn args ->
      defdelegate unquote(fun)(unquote_splicing(args)), to: QueryBuilder
    end)
  end

  ## Filter Builder

  for {fun, arity} <- FilterBuilder.__info__(:functions) do
    (1..arity)
    |> Enum.map(&Macro.var(:"arg_#{&1}", QueryBuilder))
    |> then(fn args ->
      defdelegate unquote(fun)(unquote_splicing(args)), to: FilterBuilder
    end)
  end

  ## Transform Builder

  for {fun, arity} <- TransformBuilder.__info__(:functions) do
    (1..arity)
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
