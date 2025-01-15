defmodule Supabase.PostgREST.FilterBuilder.Behaviour do
  @moduledoc "Defines the interface for the FilterBuilder module"

  alias Supabase.Fetcher

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

  @callback filter(Fetcher.t(), column :: String.t(), operator, String.Chars.t()) :: Fetcher.t()
  @callback all_of(Fetcher.t(), list(condition)) :: Fetcher.t()
  @callback all_of(Fetcher.t(), list(condition), foreign_table: String.t()) :: Fetcher.t()
  @callback any_of(Fetcher.t(), list(condition)) :: Fetcher.t()
  @callback any_of(Fetcher.t(), list(condition), foreign_table: String.t()) :: Fetcher.t()
  @callback negate(Fetcher.t(), column :: String.t(), operator, String.Chars.t()) :: Fetcher.t()
  @callback match(Fetcher.t(), query :: matcher) :: Fetcher.t()
            when matcher: %{String.t() => String.Chars.t()}
  @callback eq(Fetcher.t(), column :: String.t(), String.Chars.t()) :: Fetcher.t()
  @callback neq(Fetcher.t(), column :: String.t(), String.Chars.t()) :: Fetcher.t()
  @callback gt(Fetcher.t(), column :: String.t(), String.Chars.t()) :: Fetcher.t()
  @callback gte(Fetcher.t(), column :: String.t(), String.Chars.t()) :: Fetcher.t()
  @callback lt(Fetcher.t(), column :: String.t(), String.Chars.t()) :: Fetcher.t()
  @callback lte(Fetcher.t(), column :: String.t(), String.Chars.t()) :: Fetcher.t()
  @callback like(Fetcher.t(), column :: String.t(), String.Chars.t()) :: Fetcher.t()
  @callback like_all_of(Fetcher.t(), column :: String.t(), list(String.Chars.t())) :: Fetcher.t()
  @callback like_any_of(Fetcher.t(), column :: String.t(), list(String.Chars.t())) :: Fetcher.t()
  @callback ilike(Fetcher.t(), column :: String.t(), term) :: Fetcher.t()
  @callback ilike_all_of(Fetcher.t(), column :: String.t(), list(String.Chars.t())) :: Fetcher.t()
  @callback ilike_any_of(Fetcher.t(), column :: String.t(), list(String.Chars.t())) :: Fetcher.t()
  @callback is(Fetcher.t(), column :: String.t(), String.Chars.t()) :: Fetcher.t()
  @callback within(Fetcher.t(), column :: String.t(), String.Chars.t()) :: Fetcher.t()
  @callback contains(Fetcher.t(), column :: String.t(), list(String.Chars.t())) :: Fetcher.t()
  @callback contained_by(Fetcher.t(), column :: String.t(), list(String.Chars.t())) :: Fetcher.t()
  @callback range_lt(Fetcher.t(), column :: String.t(), String.Chars.t()) :: Fetcher.t()
  @callback range_gt(Fetcher.t(), column :: String.t(), String.Chars.t()) :: Fetcher.t()
  @callback range_gte(Fetcher.t(), column :: String.t(), String.Chars.t()) :: Fetcher.t()
  @callback range_lte(Fetcher.t(), column :: String.t(), String.Chars.t()) :: Fetcher.t()
  @callback range_adjacent(Fetcher.t(), column :: String.t(), String.Chars.t()) :: Fetcher.t()
  @callback overlaps(Fetcher.t(), column :: String.t(), list(String.Chars.t())) :: Fetcher.t()
  @callback text_search(Fetcher.t(), column :: String.t(), query :: String.t()) ::
              Fetcher.t()
  @callback text_search(
              Fetcher.t(),
              column :: String.t(),
              query :: String.t(),
              text_search_options
            ) :: Fetcher.t()
end
