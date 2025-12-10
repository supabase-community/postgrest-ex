defmodule PostgREST.MixProject do
  use Mix.Project

  @source_url "https://github.com/supabase-community/postgrest-ex"

  def project do
    [
      app: :supabase_postgrest,
      version: "1.2.1",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      description: description(),
      source_url: @source_url,
      dialyzer: [
        plt_local_path: "priv/plts",
        ignore_warnings: ".dialyzerignore",
        plt_add_apps: [:mix, :ex_unit]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp supabase_dep do
    if System.get_env("SUPABASE_LOCAL") == "1" do
      {:supabase_potion, path: "../supabase-ex"}
    else
      {:supabase_potion, "~> 0.7"}
    end
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      supabase_dep(),
      {:ecto_sql, "~> 3.13", optional: true},
      {:ex_doc, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    %{
      name: "supabase_postgrest",
      licenses: ["MIT"],
      contributors: ["zoedsoupe"],
      links: %{
        "GitHub" => @source_url,
        "Docs" => "https://hexdocs.pm/supabase_postgrest"
      },
      files: ~w[lib mix.exs README.md LICENSE]
    }
  end

  defp docs do
    [
      main: "Supabase.PostgREST",
      extras: ["README.md"]
    ]
  end

  defp description do
    """
    High level Elixir client for Supabase PostgREST.
    """
  end
end
