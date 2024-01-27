defmodule PostgREST do
  @moduledoc false

  import Kernel, except: [not: 1, and: 2, or: 2, in: 2]

  import Supabase.Client, only: [is_client: 1]

  alias PostgREST.Error
  alias PostgREST.FilterBuilder
  alias PostgREST.QueryBuilder

  def from(client, table) when is_client(client) do
    QueryBuilder.new(table, client)
  end

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

  def insert(%QueryBuilder{} = q, data, opts \\ []) do
    on_conflict = Keyword.get(opts, :on_conflict)
    upsert = if on_conflict, do: "resolution=merge-duplicates"
    returning = Keyword.get(opts, :returning, :representation)
    count = Keyword.get(opts, :count, :exact)
    prefer = Enum.join([upsert, "return=#{returning}", "count=#{count}"], ",")

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

  def delete(%QueryBuilder{} = q, opts \\ []) do
    returning = Keyword.get(opts, :returning, :representation)
    count = Keyword.get(opts, :count, :exact)
    prefer = Enum.join(["return=#{returning}", "count=#{count}"], ",")

    q
    |> QueryBuilder.change_method(:delete)
    |> QueryBuilder.add_header("Prefer", prefer)
    |> FilterBuilder.from_query_builder()
  end

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

  def filter(%FilterBuilder{} = f, column, op, value) do
    FilterBuilder.add_param(f, column, "#{op}.#{value}")
  end

  def unquote(:and)(%FilterBuilder{} = f, columns, opts \\ []) do
    columns = Enum.join(columns, ",")

    if foreign = Keyword.get(opts, :foreign_table) do
      FilterBuilder.add_param(f, "#{foreign}.and", "(#{columns})")
    else
      FilterBuilder.add_param(f, "and", "(#{columns})")
    end
  end

  def unquote(:or)(%FilterBuilder{} = f, columns, opts \\ []) do
    columns = Enum.join(columns, ",")

    if foreign = Keyword.get(opts, :foreign_table) do
      FilterBuilder.add_param(f, "#{foreign}.or", "(#{columns})")
    else
      FilterBuilder.add_param(f, "or", "(#{columns})")
    end
  end

  def unquote(:not)(%FilterBuilder{} = f, column, op, value) do
    FilterBuilder.add_param(f, column, "not.#{op}.#{value}")
  end

  def match(%FilterBuilder{} = f, %{} = query) do
    for {k, v} <- Map.to_list(query), reduce: f do
      f -> FilterBuilder.add_param(f, k, "eq.#{v}")
    end
  end

  def eq(%FilterBuilder{} = f, column, value) do
    FilterBuilder.add_param(f, column, "eq.#{value}")
  end

  def neq(%FilterBuilder{} = f, column, value) do
    FilterBuilder.add_param(f, column, "neq.#{value}")
  end

  def gt(%FilterBuilder{} = f, column, value) do
    FilterBuilder.add_param(f, column, "gt.#{value}")
  end

  def gte(%FilterBuilder{} = f, column, value) do
    FilterBuilder.add_param(f, column, "gte.#{value}")
  end

  def lt(%FilterBuilder{} = f, column, value) do
    FilterBuilder.add_param(f, column, "lt.#{value}")
  end

  def lte(%FilterBuilder{} = f, column, value) do
    FilterBuilder.add_param(f, column, "lte.#{value}")
  end

  def like(%FilterBuilder{} = f, column, value) do
    FilterBuilder.add_param(f, column, "like.#{value}")
  end

  def ilike(%FilterBuilder{} = f, column, value) do
    FilterBuilder.add_param(f, column, "ilike.#{value}")
  end

  def is(%FilterBuilder{} = f, column, value) do
    FilterBuilder.add_param(f, column, "is.#{value}")
  end

  def unquote(:in)(%FilterBuilder{} = f, column, values)
      when is_list(values) do
    FilterBuilder.add_param(f, column, "in.(#{Enum.join(values, ",")})")
  end

  def contains(%FilterBuilder{} = f, column, values)
      when is_list(values) do
    FilterBuilder.add_param(f, column, "cs.(#{Enum.join(values, ",")})")
  end

  def contained_by(%FilterBuilder{} = f, column, values)
      when is_list(values) do
    FilterBuilder.add_param(f, column, "cd.(#{Enum.join(values, ",")})")
  end

  def contains_object(%FilterBuilder{} = f, column, %{} = data) do
    case Jason.encode(data) do
      {:ok, data} -> FilterBuilder.add_param(f, column, "cs.#{data}")
      _ -> f
    end
  end

  def contained_by_object(%FilterBuilder{} = f, column, %{} = data) do
    case Jason.encode(data) do
      {:ok, data} -> FilterBuilder.add_param(f, column, "cd.#{data}")
      _ -> f
    end
  end

  def range_lt(%FilterBuilder{} = f, column, value) do
    FilterBuilder.add_param(f, column, "sl.#{value}")
  end

  def range_gt(%FilterBuilder{} = f, column, value) do
    FilterBuilder.add_param(f, column, "sr.#{value}")
  end

  def range_gte(%FilterBuilder{} = f, column, value) do
    FilterBuilder.add_param(f, column, "nxl.#{value}")
  end

  def range_lte(%FilterBuilder{} = f, column, value) do
    FilterBuilder.add_param(f, column, "nxr.#{value}")
  end

  def range_adjacent(%FilterBuilder{} = f, column, value) do
    FilterBuilder.add_param(f, column, "adj.#{value}")
  end

  def overlaps(%FilterBuilder{} = f, column, values)
      when is_list(values) do
    values
    |> Enum.map(&"%##{&1}")
    |> Enum.join(",")
    |> then(&FilterBuilder.add_param(f, column, "{#{&1}}"))
  end

  def text_search(%FilterBuilder{} = f, column, query, opts \\ []) do
    type = search_type_to_code(Keyword.get(opts, :type))
    config = if config = Keyword.get(opts, :config), do: "(#{config})", else: ""

    FilterBuilder.add_param(f, column, "#{type}fts#{config}.#{query}")
  end

  defp search_type_to_code(:plain), do: "pl"
  defp search_type_to_code(:phrase), do: "ph"
  defp search_type_to_code(:websearch), do: "w"
  defp search_type_to_code(nil), do: nil

  def limit(%FilterBuilder{} = f, count, opts \\ []) do
    if foreign = Keyword.get(opts, :foreign_table) do
      FilterBuilder.add_param(f, "#{foreign}.limit", to_string(count))
    else
      FilterBuilder.add_param(f, "limit", to_string(count))
    end
  end

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

  def single(%FilterBuilder{} = f) do
    FilterBuilder.add_header(f, "accept", "application/vnd.pgrst,object+json")
  end

  def execute(%FilterBuilder{} = f) do
    execute(f.client, f.method, f.body, f.table, f.headers, f.params)
  end

  def execute(%QueryBuilder{} = q) do
    execute(q.client, q.method, q.body, q.table, q.headers, q.params)
  end

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

  def execute_to(%FilterBuilder{} = f, schema) when is_atom(schema) do
    with {:ok, body} <- execute(f.client, f.method, f.body, f.table, f.headers, f.params) do
      if is_list(body) do
        Enum.map(body, &struct(schema, &1))
      else
        struct(schema, body)
      end
    end
  end

  def execute_to(%QueryBuilder{} = q, schema) when is_atom(schema) do
    with {:ok, body} <- execute(q.client, q.method, q.body, q.table, q.headers, q.params) do
      if is_list(body) do
        Enum.map(body, &struct(schema, &1))
      else
        struct(schema, body)
      end
    end
  end

  @api_path "rest/v1"

  defp execute(client, method, body, table, headers, params) do
    with {:ok, %Supabase.Client{} = client} = Supabase.Client.retrieve_client(client) do
      base_url = Path.join([client.conn.base_url, @api_path, table])
      accept_profile = {"accept-profile", client.db.schema}
      content_profile = {"content-profile", client.db.schema}
      additional_headers = Map.to_list(headers) ++ [accept_profile, content_profile]
      headers = Supabase.Fetcher.apply_client_headers(client, nil, additional_headers)
      query = URI.encode_query(params)
      url = URI.new!(base_url) |> URI.append_query(query)
      request = request_fun_from_method(method)

      url
      |> request.(body, headers)
      |> parse_response()
    end
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
