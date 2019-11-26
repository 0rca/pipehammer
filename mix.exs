defmodule Pipehammer.MixProject do
  use Mix.Project

  def project do
    [
      app: :pipehammer,
      aliases: aliases(),
      deps: deps(),

      # Versions
      version: "0.1.1",
      elixir: "~> 1.8",

      # Docs
      name: "Pipehammer",
      docs: docs(),

      # Hex
      description: "Boilerplate automation for pipe operator",
      package: package()
    ]
  end

  defp aliases do
    []
  end

  defp deps do
    [
      {:inch_ex, "~> 2.0", only: [:dev, :docs, :test], runtime: false},
      {:credo, "~> 1.1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      extras: ["README.md"],
      main: "readme",
      source_url: "https://github.com/0rca/pipehammer"
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/0rca/pipehammer"},
      maintainers: ["Alex Vzorov"]
    ]
  end
end
