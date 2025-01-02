defmodule Supabase.PostgRESTIntegrationTest do
  use ExUnit.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Finch

  setup do
    ExVCR.Config.cassette_library_dir("priv/cassettes")
    start_supervised!(Finch, name: TestFinch)
    :ok
  end
end
