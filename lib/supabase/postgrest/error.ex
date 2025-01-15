defmodule Supabase.PostgREST.Error do
  @moduledoc "Custom error parser for PostgREST"

  alias Supabase.Fetcher.Request
  alias Supabase.Fetcher.Response

  @behaviour Supabase.Error

  @impl true
  def from(%Response{body: body}, %Request{} = ctx) do
    metadata = Supabase.Error.make_default_http_metadata(ctx)

    metadata =
      Map.merge(metadata, %{
        database_error_hint: body[:hint],
        database_error_code: body[:code],
        database_error_detail: body[:details]
      })

    Supabase.Error.new(
      code: :database_error,
      message: body[:message],
      service: :database,
      metadata: metadata
    )
  end
end
