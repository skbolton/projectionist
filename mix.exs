defmodule Projectionist.MixProject do
  use Mix.Project

  def project do
    [
      app: :projectionist,
      version: "0.1.0",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:ecto_sql, "~> 3.0", optional: true},
      {:postgrex, ">= 0.0.0", optional: true}
    ]
  end

  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(_devel), do: ["lib", "test/support"]
end
