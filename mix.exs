defmodule Pipehammer.MixProject do
  use Mix.Project

  def project do
    [
      app: :pipehammer,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      build_path: "_build",
      config_path: "config/config.exs",
      deps_path: "deps",
      lockfile: "mix.lock",
      deps: []
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: []
    ]
  end
end
