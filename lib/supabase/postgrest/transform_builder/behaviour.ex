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
end
