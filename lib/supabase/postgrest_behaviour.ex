defmodule Supabase.PostgRESTBehaviour do
  @moduledoc false

  import Kernel, except: [not: 1, and: 2, or: 2, in: 2]

  alias Supabase.Client
  alias Supabase.PostgREST.Error
  alias Supabase.PostgREST.FilterBuilder
  alias Supabase.PostgREST.QueryBuilder

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
            when builder: QueryBuilder.t() | FilterBuilder.t()
  @callback from(Client.t(), schema :: String.t()) :: QueryBuilder.t()
  @callback select(QueryBuilder.t(), list(String.t()) | String.t()) :: FilterBuilder.t()
  @callback select(QueryBuilder.t(), list(String.t()) | String.t(), options) :: FilterBuilder.t()
  @callback insert(QueryBuilder.t(), map) :: FilterBuilder.t()
  @callback insert(QueryBuilder.t(), map, insert_options) :: FilterBuilder.t()
  @callback upsert(QueryBuilder.t(), map) :: FilterBuilder.t()
  @callback upsert(QueryBuilder.t(), map, insert_options) :: FilterBuilder.t()
  @callback delete(QueryBuilder.t()) :: FilterBuilder.t()
  @callback delete(QueryBuilder.t(), options) :: FilterBuilder.t()
  @callback update(QueryBuilder.t(), map) :: FilterBuilder.t()
  @callback update(QueryBuilder.t(), map, options) :: FilterBuilder.t()

  @type operator :: atom

  @callback filter(FilterBuilder.t(), column :: String.t(), operator, term) :: FilterBuilder.t()
  @callback unquote(:and)(FilterBuilder.t(), list(String.t())) :: FilterBuilder.t()
  @callback unquote(:and)(FilterBuilder.t(), list(String.t()), foreign_table: String.t()) ::
              FilterBuilder.t()
  @callback unquote(:or)(FilterBuilder.t(), list(String.t())) :: FilterBuilder.t()
  @callback unquote(:or)(FilterBuilder.t(), list(String.t()), foreign_table: String.t()) ::
              FilterBuilder.t()
  @callback unquote(:not)(FilterBuilder.t(), column :: String.t(), operator, term) ::
              FilterBuilder.t()
  @callback match(FilterBuilder.t(), query :: map) :: FilterBuilder.t()
  @callback eq(FilterBuilder.t(), column :: String.t(), term) :: FilterBuilder.t()
  @callback neq(FilterBuilder.t(), column :: String.t(), term) :: FilterBuilder.t()
  @callback gt(FilterBuilder.t(), column :: String.t(), term) :: FilterBuilder.t()
  @callback gte(FilterBuilder.t(), column :: String.t(), term) :: FilterBuilder.t()
  @callback lt(FilterBuilder.t(), column :: String.t(), term) :: FilterBuilder.t()
  @callback lte(FilterBuilder.t(), column :: String.t(), term) :: FilterBuilder.t()
  @callback like(FilterBuilder.t(), column :: String.t(), term) :: FilterBuilder.t()
  @callback ilike(FilterBuilder.t(), column :: String.t(), term) :: FilterBuilder.t()
  @callback is(FilterBuilder.t(), column :: String.t(), term) :: FilterBuilder.t()
  @callback unquote(:in)(FilterBuilder.t(), column :: String.t(), term) :: FilterBuilder.t()
  @callback contains(FilterBuilder.t(), column :: String.t(), list(term)) :: FilterBuilder.t()
  @callback contained_by(FilterBuilder.t(), column :: String.t(), list(term)) :: FilterBuilder.t()
  @callback contains_object(FilterBuilder.t(), column :: String.t(), data :: map) ::
              FilterBuilder.t()
  @callback contained_by_object(FilterBuilder.t(), column :: String.t(), data :: map) ::
              FilterBuilder.t()
  @callback range_lt(FilterBuilder.t(), column :: String.t(), term) :: FilterBuilder.t()
  @callback range_gt(FilterBuilder.t(), column :: String.t(), term) :: FilterBuilder.t()
  @callback range_gte(FilterBuilder.t(), column :: String.t(), term) :: FilterBuilder.t()
  @callback range_lte(FilterBuilder.t(), column :: String.t(), term) :: FilterBuilder.t()
  @callback range_adjacent(FilterBuilder.t(), column :: String.t(), term) :: FilterBuilder.t()
  @callback overlaps(FilterBuilder.t(), column :: String.t(), list(term)) :: FilterBuilder.t()
  @callback text_search(FilterBuilder.t(), column :: String.t(), query :: String.t()) ::
              FilterBuilder.t()
  @callback text_search(
              FilterBuilder.t(),
              column :: String.t(),
              query :: String.t(),
              text_search_options
            ) :: FilterBuilder.t()
  @callback limit(FilterBuilder.t(), count :: integer) :: FilterBuilder.t()
  @callback limit(FilterBuilder.t(), count :: integer, foreign_table: String.t()) ::
              FilterBuilder.t()
  @callback single(FilterBuilder.t()) :: FilterBuilder.t()
  @callback order(FilterBuilder.t(), column :: String.t(), order_options) :: FilterBuilder.t()
  @callback order(FilterBuilder.t(), column :: String.t(), order_options) :: FilterBuilder.t()
  @callback range(FilterBuilder.t(), from :: integer, to :: integer) :: FilterBuilder.t()
  @callback range(FilterBuilder.t(), from :: integer, to :: integer, foreign_table: String.t()) ::
              FilterBuilder.t()
  @callback execute(QueryBuilder.t() | FilterBuilder.t()) :: {:ok, term} | {:error, Error.t()}
  @callback execute_string(QueryBuilder.t() | FilterBuilder.t()) ::
              {:ok, binary} | {:error, Error.t() | atom}
  @callback execute_to(QueryBuilder.t() | FilterBuilder.t(), atom) ::
              {:ok, term} | {:error, Error.t() | atom}
  @callback execute_to_finch_request(QueryBuilder.t() | FilterBuilder.t()) ::
              Finch.Request.t()
end
