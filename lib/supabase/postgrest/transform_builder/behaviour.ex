defmodule Supabase.PostgREST.TransformBuilder.Behaviour do
  @moduledoc "Defines the interface for the TransformBuilder module"

  alias Supabase.Fetcher

  @type order_options :: [
          asc: boolean | nil,
          null_first: boolean | nil,
          foreign_table: String.t() | nil
        ]

  @callback limit(Fetcher.t(), count :: integer) :: Fetcher.t()
  @callback limit(Fetcher.t(), count :: integer, foreign_table: String.t()) ::
              Fetcher.t()
  @callback single(Fetcher.t()) :: Fetcher.t()
  @callback maybe_single(Fetcher.t()) :: Fetcher.t()
  @callback order(Fetcher.t(), column :: String.t(), order_options) :: Fetcher.t()
  @callback order(Fetcher.t(), column :: String.t(), order_options) :: Fetcher.t()
  @callback range(Fetcher.t(), from :: integer, to :: integer) :: Fetcher.t()
  @callback range(Fetcher.t(), from :: integer, to :: integer, foreign_table: String.t()) ::
              Fetcher.t()
  @callback rollback(Fetcher.t()) :: Fetcher.t()
  @callback returning(Fetcher.t()) :: Fetcher.t()
  @callback returning(Fetcher.t(), list(String.t()) | String.t()) :: Fetcher.t()
  @callback csv(Fetcher.t()) :: Fetcher.t()
  @callback geojson(Fetcher.t()) :: Fetcher.t()
  @callback explain(Fetcher.t(), options :: explain) :: Fetcher.t()
            when explain: list({opt, boolean} | {:format, :json | :text}),
                 opt: :analyze | :verbose | :settings | :buffers | :wal
end
