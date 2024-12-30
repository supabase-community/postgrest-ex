defmodule Supabase.PostgREST.QueryBuilder.Behaviour do
  @moduledoc "Defines the interface for the QueryBuilder module"

  alias Supabase.PostgREST.Builder

  @type options :: [count: :exact, returning: boolean | :representation]
  @type insert_options :: [count: :exact, returning: boolean | :representation, on_conflict: any]

  @callback select(Builder.t(), list(String.t()) | String.t()) :: Builder.t()
  @callback select(Builder.t(), list(String.t()) | String.t(), options) :: Builder.t()
  @callback insert(Builder.t(), map) :: Builder.t()
  @callback insert(Builder.t(), map, insert_options) :: Builder.t()
  @callback upsert(Builder.t(), map) :: Builder.t()
  @callback upsert(Builder.t(), map, insert_options) :: Builder.t()
  @callback delete(Builder.t()) :: Builder.t()
  @callback delete(Builder.t(), options) :: Builder.t()
  @callback update(Builder.t(), map) :: Builder.t()
  @callback update(Builder.t(), map, options) :: Builder.t()
end
