defmodule Supabase.PostgRESTBehaviour do
  @moduledoc false

  import Kernel, except: [not: 1, and: 2, or: 2, in: 2]

  alias Supabase.Client
  alias Supabase.PostgREST.Builder
  alias Supabase.PostgREST.Error

  @type options :: [count: :exact, returning: boolean | :representation]
  @type insert_options :: [count: :exact, returning: boolean | :representation, on_conflict: any]
  @type text_search_options :: [type: :plain | :phrase | :websearch]
  @type order_options :: [
          asc: boolean | nil,
          null_first: boolean | nil,
          foreign_table: String.t() | nil
        ]

  @type media_type ::
          :json | :csv | :openapi | :geojson | :pgrst_plan | :pgrst_object | :pgrst_array

  @callback with_custom_media_type(builder, media_type) :: builder
            when builder: Builder.t() | Builder.t()
  @callback from(Client.t(), relation :: String.t()) :: Builder.t()
  @callback schema(Builder.t(), schema :: String.t()) :: Builder.t()
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

  @type operator :: atom

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
  @callback execute(Builder.t() | Builder.t()) :: {:ok, term} | {:error, Error.t()}
  @callback execute_string(Builder.t() | Builder.t()) ::
              {:ok, binary} | {:error, Error.t() | atom}
  @callback execute_to(Builder.t() | Builder.t(), atom) ::
              {:ok, term} | {:error, Error.t() | atom}
  @callback execute_to_finch_request(Builder.t() | Builder.t()) ::
              Finch.Request.t()
end
