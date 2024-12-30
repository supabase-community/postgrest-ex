defmodule Supabase.PostgREST.FilterBuilder.Behaviour do
  @moduledoc "Defines the interface for the FilterBuilder module"

  alias Supabase.PostgREST.Builder

  @type operator :: atom
  @type text_search_options :: [type: :plain | :phrase | :websearch]

  @callback filter(Builder.t(), column :: String.t(), operator, term) :: Builder.t()
  @callback unquote(:and)(Builder.t(), list(String.t())) :: Builder.t()
  @callback unquote(:and)(Builder.t(), list(String.t()), foreign_table: String.t()) ::
              Builder.t()
  @callback unquote(:or)(Builder.t(), list(String.t())) :: Builder.t()
  @callback unquote(:or)(Builder.t(), list(String.t()), foreign_table: String.t()) ::
              Builder.t()
  @callback unquote(:not)(Builder.t(), column :: String.t(), operator, term) ::
              Builder.t()
  @callback match(Builder.t(), query :: map) :: Builder.t()
  @callback eq(Builder.t(), column :: String.t(), term) :: Builder.t()
  @callback neq(Builder.t(), column :: String.t(), term) :: Builder.t()
  @callback gt(Builder.t(), column :: String.t(), term) :: Builder.t()
  @callback gte(Builder.t(), column :: String.t(), term) :: Builder.t()
  @callback lt(Builder.t(), column :: String.t(), term) :: Builder.t()
  @callback lte(Builder.t(), column :: String.t(), term) :: Builder.t()
  @callback like(Builder.t(), column :: String.t(), term) :: Builder.t()
  @callback ilike(Builder.t(), column :: String.t(), term) :: Builder.t()
  @callback is(Builder.t(), column :: String.t(), term) :: Builder.t()
  @callback unquote(:in)(Builder.t(), column :: String.t(), term) :: Builder.t()
  @callback contains(Builder.t(), column :: String.t(), list(term)) :: Builder.t()
  @callback contained_by(Builder.t(), column :: String.t(), list(term)) :: Builder.t()
  @callback range_lt(Builder.t(), column :: String.t(), term) :: Builder.t()
  @callback range_gt(Builder.t(), column :: String.t(), term) :: Builder.t()
  @callback range_gte(Builder.t(), column :: String.t(), term) :: Builder.t()
  @callback range_lte(Builder.t(), column :: String.t(), term) :: Builder.t()
  @callback range_adjacent(Builder.t(), column :: String.t(), term) :: Builder.t()
  @callback overlaps(Builder.t(), column :: String.t(), list(term)) :: Builder.t()
  @callback text_search(Builder.t(), column :: String.t(), query :: String.t()) ::
              Builder.t()
  @callback text_search(
              Builder.t(),
              column :: String.t(),
              query :: String.t(),
              text_search_options
            ) :: Builder.t()
end
