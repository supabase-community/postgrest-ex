defmodule Supabase.PostgREST.Behaviour do
  @moduledoc "Defines the interface for the main module Supabase.PostgREST"

  alias Supabase.Client
  alias Supabase.PostgREST.Builder
  alias Supabase.PostgREST.Error

  @type media_type ::
          :json | :csv | :openapi | :geojson | :pgrst_plan | :pgrst_object | :pgrst_array

  @callback with_custom_media_type(builder, media_type) :: builder
            when builder: Builder.t() | Builder.t()
  @callback from(Client.t(), relation :: String.t()) :: Builder.t()
  @callback schema(Builder.t(), schema :: String.t()) :: Builder.t()

  @callback execute(Builder.t() | Builder.t()) :: {:ok, term} | {:error, Error.t()}
  @callback execute_to(Builder.t() | Builder.t(), atom) ::
              {:ok, term} | {:error, Error.t() | atom}
  @callback execute_to_finch_request(Builder.t() | Builder.t()) ::
              Finch.Request.t()
end
