defmodule Supabase.PostgREST.FilterBuilder.Behaviour do
  @moduledoc "Defines the interface for the FilterBuilder module"

  alias Supabase.Fetcher.Request

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

  @callback filter(Request.t(), column :: String.t(), operator, String.Chars.t()) :: Request.t()
  @callback all_of(Request.t(), list(condition)) :: Request.t()
  @callback all_of(Request.t(), list(condition), foreign_table: String.t()) :: Request.t()
  @callback any_of(Request.t(), list(condition)) :: Request.t()
  @callback any_of(Request.t(), list(condition), foreign_table: String.t()) :: Request.t()
  @callback negate(Request.t(), column :: String.t(), operator, String.Chars.t()) :: Request.t()
  @callback match(Request.t(), query :: matcher) :: Request.t()
            when matcher: %{String.t() => String.Chars.t()}
  @callback eq(Request.t(), column :: String.t(), String.Chars.t()) :: Request.t()
  @callback neq(Request.t(), column :: String.t(), String.Chars.t()) :: Request.t()
  @callback gt(Request.t(), column :: String.t(), String.Chars.t()) :: Request.t()
  @callback gte(Request.t(), column :: String.t(), String.Chars.t()) :: Request.t()
  @callback lt(Request.t(), column :: String.t(), String.Chars.t()) :: Request.t()
  @callback lte(Request.t(), column :: String.t(), String.Chars.t()) :: Request.t()
  @callback like(Request.t(), column :: String.t(), String.Chars.t()) :: Request.t()
  @callback like_all_of(Request.t(), column :: String.t(), list(String.Chars.t())) :: Request.t()
  @callback like_any_of(Request.t(), column :: String.t(), list(String.Chars.t())) :: Request.t()
  @callback ilike(Request.t(), column :: String.t(), term) :: Request.t()
  @callback ilike_all_of(Request.t(), column :: String.t(), list(String.Chars.t())) :: Request.t()
  @callback ilike_any_of(Request.t(), column :: String.t(), list(String.Chars.t())) :: Request.t()
  @callback is(Request.t(), column :: String.t(), String.Chars.t()) :: Request.t()
  @callback within(Request.t(), column :: String.t(), String.Chars.t()) :: Request.t()
  @callback contains(Request.t(), column :: String.t(), list(String.Chars.t())) :: Request.t()
  @callback contained_by(Request.t(), column :: String.t(), list(String.Chars.t())) :: Request.t()
  @callback range_lt(Request.t(), column :: String.t(), String.Chars.t()) :: Request.t()
  @callback range_gt(Request.t(), column :: String.t(), String.Chars.t()) :: Request.t()
  @callback range_gte(Request.t(), column :: String.t(), String.Chars.t()) :: Request.t()
  @callback range_lte(Request.t(), column :: String.t(), String.Chars.t()) :: Request.t()
  @callback range_adjacent(Request.t(), column :: String.t(), String.Chars.t()) :: Request.t()
  @callback overlaps(Request.t(), column :: String.t(), list(String.Chars.t())) :: Request.t()
  @callback text_search(Request.t(), column :: String.t(), query :: String.t()) ::
              Request.t()
  @callback text_search(
              Request.t(),
              column :: String.t(),
              query :: String.t(),
              text_search_options
            ) :: Request.t()
end
