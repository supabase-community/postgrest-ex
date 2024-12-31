defmodule Supabase.PostgREST.FilterBuilder.Behaviour do
  @moduledoc "Defines the interface for the FilterBuilder module"

  alias Supabase.PostgREST.Builder

  @type operator ::
          :eq
          | :gt
          | :gte
          | :lt
          | :lte
          | :neq
          | :like
          | :ilike
          | :match
          | :imatch
          | :in
          | :is
          | :isdistinct
          | :fts
          | :plfts
          | :phfts
          | :wfts
          | :cs
          | :cd
          | :ov
          | :sl
          | :sr
          | :nxr
          | :nxl
          | :adj
          | :not
          | :and
          | :or
          | :all
          | :any
  @type condition ::
          {operator, column :: String.t(), value :: String.Chars.t()}
          | {:not, condition}
          | {:and | :or, list(condition)}
          | {:eq | :like | :ilike | :gt | :gte | :lt | :lte | :match | :imatch,
             column :: String.t(), pattern :: list(String.Chars.t())}
          | {:eq | :like | :ilike | :gt | :gte | :lt | :lte | :match | :imatch,
             column :: String.t(), pattern :: list(String.Chars.t()),
             list({:any | :all, boolean})}
  @type text_search_options :: [type: :plain | :phrase | :websearch]

  @callback filter(Builder.t(), column :: String.t(), operator, String.Chars.t()) :: Builder.t()
  @callback all_of(Builder.t(), list(condition)) :: Builder.t()
  @callback all_of(Builder.t(), list(condition), foreign_table: String.t()) :: Builder.t()
  @callback any_of(Builder.t(), list(condition)) :: Builder.t()
  @callback any_of(Builder.t(), list(condition), foreign_table: String.t()) :: Builder.t()
  @callback negate(Builder.t(), column :: String.t(), operator, String.Chars.t()) :: Builder.t()
  @callback match(Builder.t(), query :: matcher) :: Builder.t()
            when matcher: %{String.t() => String.Chars.t()}
  @callback eq(Builder.t(), column :: String.t(), String.Chars.t()) :: Builder.t()
  @callback neq(Builder.t(), column :: String.t(), String.Chars.t()) :: Builder.t()
  @callback gt(Builder.t(), column :: String.t(), String.Chars.t()) :: Builder.t()
  @callback gte(Builder.t(), column :: String.t(), String.Chars.t()) :: Builder.t()
  @callback lt(Builder.t(), column :: String.t(), String.Chars.t()) :: Builder.t()
  @callback lte(Builder.t(), column :: String.t(), String.Chars.t()) :: Builder.t()
  @callback like(Builder.t(), column :: String.t(), String.Chars.t()) :: Builder.t()
  @callback like_all_of(Builder.t(), column :: String.t(), list(String.Chars.t())) :: Builder.t()
  @callback like_any_of(Builder.t(), column :: String.t(), list(String.Chars.t())) :: Builder.t()
  @callback ilike(Builder.t(), column :: String.t(), term) :: Builder.t()
  @callback ilike_all_of(Builder.t(), column :: String.t(), list(String.Chars.t())) :: Builder.t()
  @callback ilike_any_of(Builder.t(), column :: String.t(), list(String.Chars.t())) :: Builder.t()
  @callback is(Builder.t(), column :: String.t(), String.Chars.t()) :: Builder.t()
  @callback within(Builder.t(), column :: String.t(), String.Chars.t()) :: Builder.t()
  @callback contains(Builder.t(), column :: String.t(), list(String.Chars.t())) :: Builder.t()
  @callback contained_by(Builder.t(), column :: String.t(), list(String.Chars.t())) :: Builder.t()
  @callback range_lt(Builder.t(), column :: String.t(), String.Chars.t()) :: Builder.t()
  @callback range_gt(Builder.t(), column :: String.t(), String.Chars.t()) :: Builder.t()
  @callback range_gte(Builder.t(), column :: String.t(), String.Chars.t()) :: Builder.t()
  @callback range_lte(Builder.t(), column :: String.t(), String.Chars.t()) :: Builder.t()
  @callback range_adjacent(Builder.t(), column :: String.t(), String.Chars.t()) :: Builder.t()
  @callback overlaps(Builder.t(), column :: String.t(), list(String.Chars.t())) :: Builder.t()
  @callback text_search(Builder.t(), column :: String.t(), query :: String.t()) ::
              Builder.t()
  @callback text_search(
              Builder.t(),
              column :: String.t(),
              query :: String.t(),
              text_search_options
            ) :: Builder.t()
end
