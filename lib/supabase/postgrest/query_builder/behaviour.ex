defmodule Supabase.PostgREST.QueryBuilder.Behaviour do
  @moduledoc "Defines the interface for the QueryBuilder module"

  alias Supabase.Fetcher

  @type options :: [count: :exact, returning: boolean | :representation]
  @type insert_options :: [count: :exact, returning: boolean | :representation, on_conflict: any]

  @callback select(Fetcher.t(), list(String.t()) | String.t()) :: Fetcher.t()
  @callback select(Fetcher.t(), list(String.t()) | String.t(), options) :: Fetcher.t()
  @callback insert(Fetcher.t(), map) :: Fetcher.t()
  @callback insert(Fetcher.t(), map, insert_options) :: Fetcher.t()
  @callback upsert(Fetcher.t(), map) :: Fetcher.t()
  @callback upsert(Fetcher.t(), map, insert_options) :: Fetcher.t()
  @callback delete(Fetcher.t()) :: Fetcher.t()
  @callback delete(Fetcher.t(), options) :: Fetcher.t()
  @callback update(Fetcher.t(), map) :: Fetcher.t()
  @callback update(Fetcher.t(), map, options) :: Fetcher.t()
end
