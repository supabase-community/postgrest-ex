defmodule Supabase.PostgREST.QueryBuilder do
  @moduledoc false

  defstruct [:table, :method, :body, :params, :headers, :client]

  @type t :: %__MODULE__{
          table: String.t(),
          method: :get | :post | :put | :patch | :delete,
          params: map,
          headers: map,
          body: binary,
          client: Supabase.Client.t()
        }

  def new(table, client) do
    %__MODULE__{
      table: table,
      method: :get,
      params: %{},
      headers: %{},
      body: "",
      client: client
    }
  end

  def change_method(%__MODULE__{} = q, method) do
    %{q | method: method}
  end

  def change_body(%__MODULE__{} = q, body) do
    %{q | body: body}
  end

  def add_header(%__MODULE__{} = q, "Prefer", value) do
    %{q | headers: Map.put(q.headers, "Prefer", value)}
  end

  def add_header(%__MODULE__{} = q, _, nil), do: q

  def add_header(%__MODULE__{} = q, key, value) do
    %{q | headers: Map.put(q.headers, key, value)}
  end

  def del_header(%__MODULE__{} = q, key) do
    %{q | headers: Map.delete(q.headers, key)}
  end

  def add_param(%__MODULE__{} = q, _, nil), do: q

  def add_param(%__MODULE__{} = q, key, value) do
    %{q | params: Map.put(q.params, key, value)}
  end

  def del_param(%__MODULE__{} = q, key) do
    %{q | params: Map.delete(q.params, key)}
  end
end
