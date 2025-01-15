defmodule Supabase.PostgREST.QueryBuilder.Behaviour do
  @moduledoc "Defines the interface for the QueryBuilder module"

  alias Supabase.Fetcher.Request

  @type options :: [count: :exact, returning: boolean | :representation]
  @type insert_options :: [count: :exact, returning: boolean | :representation, on_conflict: any]

  @callback select(Request.t(), list(String.t()) | String.t()) :: Request.t()
  @callback select(Request.t(), list(String.t()) | String.t(), options) :: Request.t()
  @callback insert(Request.t(), map) :: Request.t()
  @callback insert(Request.t(), map, insert_options) :: Request.t()
  @callback upsert(Request.t(), map) :: Request.t()
  @callback upsert(Request.t(), map, insert_options) :: Request.t()
  @callback delete(Request.t()) :: Request.t()
  @callback delete(Request.t(), options) :: Request.t()
  @callback update(Request.t(), map) :: Request.t()
  @callback update(Request.t(), map, options) :: Request.t()
end
