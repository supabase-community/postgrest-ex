defmodule Supabase.PostgREST.TransformBuilder.Behaviour do
  @moduledoc "Defines the interface for the TransformBuilder module"

  alias Supabase.Fetcher.Request

  @type order_options :: [
          asc: boolean | nil,
          null_first: boolean | nil,
          foreign_table: String.t() | nil
        ]

  @callback limit(Request.t(), count :: integer) :: Request.t()
  @callback limit(Request.t(), count :: integer, foreign_table: String.t()) ::
              Request.t()
  @callback single(Request.t()) :: Request.t()
  @callback maybe_single(Request.t()) :: Request.t()
  @callback order(Request.t(), column :: String.t(), order_options) :: Request.t()
  @callback order(Request.t(), column :: String.t(), order_options) :: Request.t()
  @callback range(Request.t(), from :: integer, to :: integer) :: Request.t()
  @callback range(Request.t(), from :: integer, to :: integer, foreign_table: String.t()) ::
              Request.t()
  @callback rollback(Request.t()) :: Request.t()
  @callback returning(Request.t()) :: Request.t()
  @callback returning(Request.t(), list(String.t()) | String.t()) :: Request.t()
  @callback csv(Request.t()) :: Request.t()
  @callback geojson(Request.t()) :: Request.t()
  @callback explain(Request.t(), options :: explain) :: Request.t()
            when explain: list({opt, boolean} | {:format, :json | :text}),
                 opt: :analyze | :verbose | :settings | :buffers | :wal
end
