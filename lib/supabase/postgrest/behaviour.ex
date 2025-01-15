defmodule Supabase.PostgREST.Behaviour do
  @moduledoc "Defines the interface for the main module Supabase.PostgREST"

  alias Supabase.Client
  alias Supabase.Fetcher.Request

  @type media_type ::
          :json | :csv | :openapi | :geojson | :pgrst_plan | :pgrst_object | :pgrst_array

  @callback with_custom_media_type(Request.t(), media_type) :: Request.t()
  @callback from(Client.t(), relation :: String.t()) :: Request.t()
  @callback schema(Request.t(), schema :: String.t()) :: Request.t()

  @callback execute(Request.t()) :: Supabase.result(term)
  @callback execute_to(Request.t(), module) :: Supabase.result(term)
  @callback execute_to_finch_request(Request.t()) :: Finch.Request.t()
end
