defmodule Mix.Tasks.Supabase.Gen.Schema do
  @moduledoc false

  use Mix.Task

  alias Supabase.PostgREST.Parser

  @impl Mix.Task
  def run(args) do
    with {:ok, dump} <- dump_schema(args),
         {:ok, ast} <- Parser.run(dump) do
      dbg(ast)
    else
      {:error, err} -> Mix.shell().error(err)
    end
  end

  defp dump_schema(args) do
    if bin = System.find_executable("supabase") do
      case System.cmd(bin, ["db", "dump" | args], stderr_to_stdout: true) do
        {out, 0} -> {:ok, out}
        {error, _} -> {:error, error}
      end
    else
      Mix.shell().error("supabase bin not found")
    end
  end
end
