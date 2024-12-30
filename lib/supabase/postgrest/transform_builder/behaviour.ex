defmodule Supabase.PostgREST.TransformBuilder.Behaviour do
  @moduledoc "Defines the interface for the TransformBuilder module"

  alias Supabase.PostgREST.Builder

  @type order_options :: [
          asc: boolean | nil,
          null_first: boolean | nil,
          foreign_table: String.t() | nil
        ]

  @callback limit(Builder.t(), count :: integer) :: Builder.t()
  @callback limit(Builder.t(), count :: integer, foreign_table: String.t()) ::
              Builder.t()
  @callback single(Builder.t()) :: Builder.t()
  @callback maybe_single(Builder.t()) :: Builder.t()
  @callback order(Builder.t(), column :: String.t(), order_options) :: Builder.t()
  @callback order(Builder.t(), column :: String.t(), order_options) :: Builder.t()
  @callback range(Builder.t(), from :: integer, to :: integer) :: Builder.t()
  @callback range(Builder.t(), from :: integer, to :: integer, foreign_table: String.t()) ::
              Builder.t()
  @callback rollback(Builder.t()) :: Builder.t()
  @callback returning(Builder.t()) :: Builder.t()
  @callback returning(Builder.t(), list(String.t()) | String.t()) :: Builder.t()
  @callback csv(Builder.t()) :: Builder.t()
  @callback geojson(Builder.t()) :: Builder.t()
  @callback explain(Builder.t(), options :: explain) :: Builder.t()
            when explain: list({opt, boolean} | {:format, :json | :text}),
                 opt: :analyze | :verbose | :settings | :buffers | :wal
end
