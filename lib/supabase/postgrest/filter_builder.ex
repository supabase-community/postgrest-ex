defmodule Supabase.PostgREST.FilterBuilder do
  alias Supabase.PostgREST.QueryBuilder

  defstruct [:method, :body, :table, :headers, :params, :client]

  def new, do: %__MODULE__{}

  def from_query_builder(%QueryBuilder{} = q) do
    %__MODULE__{
      table: q.table,
      params: q.params,
      headers: q.headers,
      body: q.body,
      client: q.client,
      method: q.method
    }
  end

  def add_param(%__MODULE__{} = f, _, nil), do: f

  def add_param(%__MODULE__{} = f, key, value) do
    %{f | params: Map.put(f.params, key, value)}
  end

  def add_header(%__MODULE__{} = f, _, nil), do: f

  def add_header(%__MODULE__{} = f, key, value) do
    %{f | headers: Map.put(f.headers, key, value)}
  end
end
