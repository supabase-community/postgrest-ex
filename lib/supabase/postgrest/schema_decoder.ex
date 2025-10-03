defmodule Supabase.PostgREST.SchemaDecoder do
  @moduledoc "Custom body decoder that decodes a PostgREST response into a custom schema"

  alias Supabase.Fetcher.JSONDecoder
  alias Supabase.Fetcher.Response

  @behaviour Supabase.Fetcher.BodyDecoder

  @impl true
  def decode(%Response{} = resp, opts \\ []) do
    schema = Keyword.fetch!(opts, :schema)

    with {:ok, body} <- JSONDecoder.decode(resp, []) do
      body = atom_keys(body)

      cond do
        resp.status < 400 and is_list(body) ->
          {:ok, Enum.map(body, &struct(schema, &1))}

        resp.status < 400 ->
          {:ok, struct(schema, body)}

        true ->
          {:ok, body}
      end
    end
  end

  defp atom_keys(body) when is_list(body) do
    Enum.map(body, &atom_keys/1)
  end

  defp atom_keys(body) when is_map(body) do
    Map.new(body, fn
      {k, v} when is_map(v) -> {String.to_atom(k), atom_keys(v)}
      {k, v} -> {String.to_atom(k), v}
    end)
  end
end
