defmodule Supabase.PostgREST.Builder do
  @moduledoc """
  Defines a struct to centralize and accumulate data to
  be sent to the PostgREST server, parsed.
  """

  alias Supabase.Client

  defstruct ~w[method body url headers params client schema]a

  @type t :: %__MODULE__{
          url: String.t(),
          method: :get | :post | :put | :patch | :delete,
          params: %{String.t() => String.t()},
          headers: %{String.t() => String.t()},
          body: map,
          client: Supabase.Client.t(),
          schema: String.t()
        }

  defp get_version do
    :supabase_postgrest
    |> :application.get_key(:vsn)
    |> elem(1)
    |> List.to_string()
  end

  @doc "Creates a new `#{__MODULE__}` instance"
  def new(%Client{} = client, relation: relation) do
    %__MODULE__{
      schema: client.db.schema,
      method: :get,
      params: %{},
      url:
        URI.parse(client.conn.base_url)
        |> URI.append_path("/rest/v1")
        |> URI.append_path("/" <> relation),
      headers: %{
        "x-client-info" => "postgrest-ex/#{get_version()}",
        "accept-profile" => client.db.schema,
        "content-profile" => client.db.schema,
        "content-type" => "application/json"
      }
    }
  end

  @doc """
  Updates the key `#{__MODULE__}.params` and adds a new query params
  """
  def add_query_param(%__MODULE__{} = b, _, nil), do: b

  def add_query_param(%__MODULE__{} = b, key, value) do
    %{b | params: Map.put(b.params, key, value)}
  end

  @doc """
  Updates the key `#{__MODULE__}.headers` and adds a new request header
  """
  def add_request_header(%__MODULE__{} = b, _, nil), do: b

  def add_request_header(%__MODULE__{} = b, key, value) do
    %{b | headers: Map.put(b.headers, key, value)}
  end

  @doc "Removes a request header"
  def del_request_header(%__MODULE__{} = b, key) do
    %{b | headers: Map.delete(b.headers, key)}
  end

  @doc "Changes the HTTP method that'll be used to execute the query"
  def change_method(%__MODULE__{} = q, method) do
    %{q | method: method}
  end

  @doc "Changes the request body that will be sent to the PostgREST server"
  def change_body(%__MODULE__{} = q, body) do
    %{q | body: body}
  end
end
