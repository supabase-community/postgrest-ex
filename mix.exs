defmodule PostgREST.MixProject do
  use Mix.Project

  @source_url "https://github.com/zoedsoupe/postgrest-ex"

  def project do
    [
      app: :supabase_postgrest,
      version: "0.1.5",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      description: description(),
      source_url: @source_url,
      preferred_cli_env: [
        vcr: :test,
        "vcr.delete": :test,
        "vcr.check": :test,
        "vcr.show": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:supabase_potion, "~> 0.4"},
      {:ex_doc, ">= 0.0.0", runtime: false},
      {:exvcr, "~> 0.11", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev], runtime: false}
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
