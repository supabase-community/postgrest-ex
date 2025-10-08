defmodule Mix.Tasks.Supabase.Gen.Schema do
  @moduledoc false

  @switches [
    local: :boolean,
    dry_run: :boolean,
    output_dir: :boolean,
    rls: :boolean,
    schema: :keep
  ]
end
