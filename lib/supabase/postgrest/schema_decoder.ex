defmodule Supabase.PostgREST.SchemaDecoder do
  @moduledoc "Custom body decoder that decodes a PostgREST response into a custom schema"

  alias Supabase.Fetcher.JSONDecoder
  alias Supabase.Fetcher.Response

  @behaviour Supabase.Fetcher.BodyDecoder

  @impl true
  def decode(%Response{} = resp, opts \\ []) do
    schema = Keyword.fetch!(opts, :schema)

    with {:ok, body} <- JSONDecoder.decode(resp, keys: :atoms) do
      cond do
        resp.status < 400 and is_list(body) -> {:ok, Enum.map(body, &struct(schema, &1))}
        resp.status < 400 -> {:ok, struct(schema, body)}
        true -> {:ok, body}
      end
    end
  end
end
